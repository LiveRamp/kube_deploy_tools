require 'date'
require 'json'
require 'net/http'
require 'open-uri'
require 'optparse'
require 'set'
require 'uri'
require 'yaml'

require 'kube_deploy_tools/deploy_config_file'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/image_registry'
require 'kube_deploy_tools/image_registry/driver'
require 'kube_deploy_tools/shellrunner'


IMAGES_FILE = 'images.yaml'

module KubeDeployTools
  class Expire
    def initialize(config_file, artifactory_repo, artifactory_pattern, retention, dryrun)
      @artifactory_username = ENV.fetch('ARTIFACTORY_USERNAME')
      @artifactory_password = ENV.fetch('ARTIFACTORY_PASSWORD')
      @artifactory_host = ENV.fetch('ARTIFACTORY_HOST', 'https://***REMOVED***/artifactory')

      @config_file = config_file
      @dryrun = dryrun

      config = DeployConfigFile.new(config_file)
      @registries = config.image_registries
      @drivers = @registries.map do |_, registry|
        driver_class = ImageRegistry::Driver::MAPPINGS.fetch(registry.driver)
        [registry.name, driver_class.new(registry: registry)]
      end.to_h
      @sweeper_configs = config.expiration

      if ! artifactory_pattern.blank?
        @sweeper_configs = [
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
      @sweeper_configs.each do |config|
        artifactory_builds, built_artifacts_files = search_artifactory(config)

        # Need to fetch the other images before removing the files from artifactory
        images = fetch_built_artifacts_files(built_artifacts_files)
        @drivers.each do |name, driver|
          driver.authorize unless @dryrun
          driver.delete_images(images.fetch(name, []), @dryrun)
          driver.unauthorize unless @dryrun
        end

        # On success of all image deletions, now safe to trash the metadata.
        remove_from_artifactory(artifactory_builds)
      end
    end

    # Find the containers that are past their expiry time
    # on artifactory
    def search_artifactory(config)
      #{{"job"=>prefix, "build"=>build, "repository"=>repository}=>{ files=>[], "created"=>created}}
      images_to_remove = {}
      built_artifacts_files = []

      repo_name = config.fetch('repository')

      uri = URI.parse("#{@artifactory_host}/api/search/aql")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')

      config.fetch('prefixes').each do |config|
        request = Net::HTTP::Post.new(uri)
        request.basic_auth @artifactory_username, @artifactory_password
        request.content_type = "text/plain"

        # this is using the AQL api
        # https://www.jfrog.com/confluence/display/RTF/Artifactory+REST+API#ArtifactoryRESTAPI-ArtifactoryQueryLanguage(AQL)
        # AQL docs: https://www.jfrog.com/confluence/display/RTF/Artifactory+Query+Language
        request.body = <<~POST_BODY
        items.find(
            {"repo":{"$eq":"#{repo_name}"}},
            {"path":{"$match":"#{config['pattern']}"}},
            {"created":{"$before":"#{format_retention(config['retention'])}"}}
        ).include("name", "created", "path", "repo")
        POST_BODY

        response = http.request(request)
        response_body = JSON.parse(response.body)

        if response.code != '200'
          KubeDeployTools::Logger.error("Error in fetching #{repo_name} search results #{response.code}: #{response.body}")
          next
        else
          response_body['results'].each do |res|
            prefix, _, build = res['path'].rpartition('/')
            file = res['name']
            uri_result = "#{@artifactory_host}/api/storage/#{repo_name}/#{prefix}/#{build}/#{file}"
            created = DateTime.strptime(res['created'][0 .. 10], '%Y-%m-%d').to_time

            # Pull out the images.yaml files for reading
            if file.eql? IMAGES_FILE
              built_artifacts_files.push(uri_result)
            end

            key = {'job' => prefix, 'build' => build, 'repository' => repo_name}
            Logger.debug "remove #{key} created #{created}"
            if images_to_remove.has_key?(key)
              images_to_remove[key]['files'].push(file)
            else
              images_to_remove[key] = {'files' => [file], 'created' => created}
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
            http.use_ssl = (uri.scheme == 'https')
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

    # To support old style retention format (ex. 1M -> 1mo)
    def format_retention(retention)
      retention.gsub /[M,m]$/, 'mo'
    end

  end
end
