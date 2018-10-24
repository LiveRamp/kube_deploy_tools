require 'date'
require 'json'
require 'net/http'
require 'open-uri'
require 'optparse'
require 'set'
require 'uri'
require 'yaml'

require 'kube_deploy_tools/deploy_artifact'
require 'kube_deploy_tools/deploy_config_file'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/image_registry'
require 'kube_deploy_tools/image_registry/driver'
require 'kube_deploy_tools/shellrunner'


IMAGES_FILE = 'images.yaml'

module KubeDeployTools
  class Sweeper
    def initialize(config_file, artifactory_repo, artifactory_pattern, retention, dryrun)
      @artifactory_username = ENV.fetch('ARTIFACTORY_USERNAME')
      @artifactory_password = ENV.fetch('ARTIFACTORY_PASSWORD')
      @artifactory_host = ENV.fetch('ARTIFACTORY_HOST', KubeDeployTools::ARTIFACTORY_ENDPOINT)

      @config_file = config_file
      @dryrun = dryrun

      # Load file once for registries & drivers
      @registries = DeployConfigFile.new(config_file).image_registries
      @drivers = @registries.map do |_, registry|
        driver_class = ImageRegistry::Driver::MAPPINGS.fetch(registry.driver)
        [registry.name, driver_class.new(registry: registry)]
      end.to_h

      if @config_file && File.exists?(@config_file)
        # Load file again for sweeper data
        @configs = YAML.load_file(@config_file).fetch('sweeper')
      else
          KubeDeployTools::Logger.error("The config file '#{@config_file}' does not exist")
      end

      if ! artifactory_pattern.blank?
        @configs = [
          {
            'repository' => artifactory_repo,
            'prefixes' => [
              'pattern' => artifactory_pattern,
              'retention' => retention,
            ]
          }
        ]
      end
    end

    def remove_images
      @configs.each do |config|
        artifactory_builds, built_artifacts_files = search_artifactory(config)

        # Need to fetch the other images before removing the files from artifactory
        images = fetch_built_artifacts_files(built_artifacts_files)
        @drivers.fetch('gcp').delete_images(images.fetch('gcp', []), @dryrun)
        @drivers.fetch('aws').delete_images(images.fetch('aws', []), @dryrun)

        # On success of all image deletions, now safe to trash the metadata.
        remove_from_artifactory(artifactory_builds)
      end
    end

    # Find the containers that are past their expiry time
    # on artifactory
    def search_artifactory(config)
      largest_retention = 0
      config.fetch('prefixes').each do |config|
        this_retention = human_duration_in_seconds(config['retention'])
        if this_retention > largest_retention
          largest_retention = this_retention
        end
      end

      repo_name = config.fetch('repository')
      prefixes = config.fetch('prefixes')
      to = (Time.now - largest_retention).to_i * 1000

      uri = URI.parse("#{@artifactory_host}/api/search/creation")
      uri.query = "to=#{to}&from=0&repos=#{repo_name}"
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri)
      request.basic_auth @artifactory_username, @artifactory_password
      response = http.request(request)
      response_body = JSON.parse(response.body)

      #{{"job"=>prefix, "build"=>build, "repository"=>repository}=>{ files=>[], "created"=>created}}
      images_to_remove = {}
      built_artifacts_files = []
      if response.code != '200'
        KubeDeployTools::Logger.error("Error in fetching #{repo_name} search results #{response.code}: #{response.body}")
        return images_to_remove, built_artifacts_files
      else
        response_body['results'].each do |res|
          uri_result = res['uri']
          uri_split = uri_result.split('/')

          # The uri has the structure of:
          # {host}/api/storage/{repo_name}/{prefix}/{build}/{file}
          prefix_index = uri_split.find_index(repo_name) + 1
          prefix = uri_split[prefix_index]
          build = uri_split[prefix_index + 1]
          file = uri_split[prefix_index + 2]

          created = DateTime.strptime(res['created'][0 .. 10], '%Y-%m-%d').to_time
          config.fetch('prefixes', []).each do |item|
            pattern = item.fetch('pattern')
            retention = human_duration_in_seconds(item.fetch('retention'))
            horizon = Time.now - retention

            if not File.fnmatch?(pattern, prefix)
              Logger.debug "skip #{prefix} build #{build} did not match #{pattern}"
            elsif created > horizon
              Logger.debug "skip #{prefix} build #{build} horizon #{horizon} created #{created}"
            else
              # Pull out the images.yaml files for reading
              if file.eql? IMAGES_FILE
                built_artifacts_files.push(uri_result)
              end

              key = {'job' => prefix, 'build' => build, 'repository' => repo_name}
              Logger.debug "remove #{key} horizon #{horizon} created #{created}"
              if images_to_remove.has_key?(key)
                images_to_remove[key]['files'].push(file)
              else
                images_to_remove[key] = {'files' => [file], 'created' => created}
              end
            end
          end
        end
      end

      return images_to_remove, built_artifacts_files
    end

    # Method to fetch and read images.yaml
    def fetch_built_artifacts_files(built_artifacts_files)
      prefix_images = Hash[@registries.map {|reg, _| [reg, []]}]
      prefix_to_registry = Hash[@registries.map {|reg, info| [info.prefix, reg]}]

      # built_artifacts_files is a list of artifactory urls
      # pointing to the specific images.yaml files

      built_artifacts_files.each do |image_uri|
        image_yaml = nil
        # The download file is not at @artifactory_host/api/storage/<BUILD_INFO>
        # so need to remove the 'api/storage' since at @artifactory_host/<BUILD_INFO>
        # Using open-uri reads
        image_uri = image_uri.sub('api/storage/', '')
        images_file = open(image_uri)
        begin
          image_yaml = YAML.load(images_file.read)
        rescue OpenURI::HTTPError => e
          Logger.error("Error in reading file #{image_uri}: #{e.message}")
          next
        end

        # Some YAML files are blank, because Ruby, this returns 'false'
        # which wouldn't be a valid file anyway so just skip it.
        if image_yaml == false
          Logger.warn("Invalid images.yaml file: #{image_uri}, skipping")
          next
        end

        # Sort into prefixes
        image_yaml['images'].each do |img|
           # Do not remove the 'latest' image since it is continually
           # updated with each build so it will be the latest version
           # NOT the one associated with the build in images.yaml
          if img.end_with? 'latest'
            next
          end

          prefix_to_registry.each_key.each do |pre|
            if img.include? pre
              prefix_images[prefix_to_registry[pre]].push(img)
              next
            end
          end
        end
      end
      return prefix_images
    end

    # Remove the expired binaries from Artifactory
    def remove_from_artifactory(builds)
      builds.each do |job, files|
        build_path = "#{job['repository']}/#{job['job']}/#{job['build']}"

        # This is to remove the folder which the files were in once all the files
        # are deleted
        files['files'].push(nil)

        files['files'].each do |file|
          if file.nil?
            file_path = ''
          else
            file_path = "/#{file}"
          end
          remove_path = "#{@artifactory_host}/#{build_path}#{file_path}"

          if @dryrun
            Logger.info("DRYRUN: Removing #{remove_path}")
          else
            uri = URI.parse(remove_path)
            http = Net::HTTP.new(uri.host, uri.port)
            request = Net::HTTP::Delete.new(uri)
            request.basic_auth @artifactory_username, @artifactory_password
            response = http.request(request)

            if response.code != '200' && response.code != '204'
              Logger.error("Unsuccessful at deleting #{remove_path}: #{response.code}, #{response.message}")
            else
              Logger.info("Successfully removed build #{remove_path}")
            end
          end
        end
      end
    end

    # Function to convert the config times of format "<>M" or "<>d"
    # to seconds
    def human_duration_in_seconds(time)
      if time.index("d") != nil
        time = time[0...time.index("d")].to_i
      elsif time.index("M") != nil
        # Converting the string to days of retention and averaging
        # 30 days in a month
        time = time[0...time.index("M")].to_i * 30
      else
        raise "Invalid retention value, unexpected input #{time}"
      end
      return time * 60 * 60 * 24
    end
  end
end
