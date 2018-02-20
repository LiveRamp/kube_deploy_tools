require 'date'
require 'json'
require 'net/http'
require 'open-uri'
require 'optparse'
require 'set'
require 'uri'
require 'yaml'

require 'kube_deploy_tools/cluster_config'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/publish_container'
require 'kube_deploy_tools/publish_container/driver/aws'
require 'kube_deploy_tools/publish_container/driver/gcp'
require 'kube_deploy_tools/shellrunner'

ARTIFACTORY_USERNAME = ENV.fetch('ARTIFACTORY_USERNAME')
ARTIFACTORY_PASSWORD = ENV.fetch('ARTIFACTORY_PASSWORD')
ARTIFACTORY_HOST = ENV.fetch('ARTIFACTORY_HOST')

IMAGES_FILE = 'images.yaml'

module KubeDeployTools
  class Sweeper
    def initialize(config_file, dryrun)
      @config_file = config_file
      @dryrun = dryrun
    end

    def remove_images
      if not File.exists? @config_file
        KubeDeployTools::Logger.error("This config file does not exist: #{@config_file}")
      end

      configs = YAML.load_file(@config_file)
      configs.each do |config|
        retention = human_duration_in_seconds(config['retention'])
        repo = config['repository']
        prefixes = config['prefix']
        remove(repo, retention, prefixes)
      end
    end
    
    # Find the containers that are past their expiry time
    # on artifactory
    def search_artifactory(retention, repo_name, prefixes)
      time_now = Time.now
      to = (time_now - retention).to_i * 1000
      from = 0
    
      http_path = "#{ARTIFACTORY_HOST}/api/search/creation"
      uri = URI.parse(http_path)
      uri.query = "to=#{to}&from=#{from}&repos=#{repo_name}"
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri)
      request.basic_auth ARTIFACTORY_USERNAME, ARTIFACTORY_PASSWORD
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
    
          if not prefixes.include?(prefix)
            next
          end

          # Pull out the images.yaml files for reading
          if file.eql? IMAGES_FILE
            built_artifacts_files.push(uri_result)
          end

          key = {'job' => prefix, 'build' => build, 'repository' => repo_name}
          if images_to_remove.has_key?(key)
            images_to_remove[key]['files'].push(file)
          else
            created = DateTime.strptime(res['created'][0 .. 10], '%Y-%m-%d')
            images_to_remove[key] = {'files' => [file], 'created' => created}
          end
        end
      end

      return images_to_remove, built_artifacts_files
    end
    
    # Method to fetch and read images.yaml
    def fetch_built_artifacts_files(built_artifacts_files)
      prefix_images = Hash[REGISTRIES.map {|name, values| [name, []]}]
    
      # built_artifacts_files is a list of artifactory urls
      # pointing to the specific images.yaml files
      
      built_artifacts_files.each do |image_uri|
        image_yaml = nil
        begin
          # The download file is not at ARTIFACTORY_HOST/api/storage/<BUILD_INFO>
          # so need to remove the 'api/storage' since at ARTIFACTORY_HOST/<BUILD_INFO>
          # Using open-uri reads
          images_file = open(image_uri.sub('api/storage/', ''))
          image_yaml = YAML.load(images_file.read)
        rescue OpenURI::HTTPError => e
          Logger.error("Error in reading file #{image_uri}: #{e.message}")
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
    
          PREFIX_TO_REGISTRY.each_key.each do |pre|
            if img.include? pre
              prefix_images[PREFIX_TO_REGISTRY[pre]].push(img)
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
    
        # Check if the job has an images.yaml file
        # TODO (efries) Remove this section once all artifacts have images.yaml
        if files['files'].grep(/images.yaml/).empty?
          search_all_the_files(files['files'], build_path)
        end

        # This is to remove the folder which the files were in once all the files
        # are deleted
        files['files'].push(' ')

        files['files'].each do |file|
          file_path = file.strip.empty? ? '' : "/#{file}"
          remove_path = "#{ARTIFACTORY_HOST}/#{build_path}#{file_path}"

          if @dryrun
            Logger.info("DRYRUN: Removing #{remove_path}")
          else
            uri = URI.parse(remove_path)
            http = Net::HTTP.new(uri.host, uri.port)
            request = Net::HTTP::Delete.new(uri)
            request.basic_auth ARTIFACTORY_USERNAME, ARTIFACTORY_PASSWORD
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
    
    # Remove the expired container images from GCR
    # Link: https://cloud.google.com/container-registry/docs/managing#deleting_images
    def remove_from_gcp(image_ids)
      image_ids.each do |id|
        # Need the id path to be [HOSTNAME]/[PROJECT-ID]/[IMAGE]<:[TAG]|@[DIGEST]>
        PublishContainer::Driver::Gcp.new(registry: REGISTRIES['gcp']).delete_image(id, @dryrun)
      end
    end
    
    # Remove the expired containers images from ECR
    # Link: https://docs.aws.amazon.com/AmazonECR/latest/userguide/delete_image.html
    def remove_from_ecr(image_ids)
      image_ids.each do |img|
        # Need the image tag and repository, not full path of the image
        val = img.partition "#{REGISTRIES['aws']['prefix']}/"
        repo_image = val.last.rpartition(':')
        repository = repo_image.first
        image = repo_image.last
        aws_driver = PublishContainer::Driver::Aws.new(registry: REGISTRIES['aws']).delete_image(repository, image, @dryrun)
      end
    end
    
    def remove(repository, retention, prefixes)
      artifactory_builds, built_artifacts_files = search_artifactory(retention, repository, prefixes)
      # Need to fetch the other images before removing the files from artifactory
      images = fetch_built_artifacts_files(built_artifacts_files)
      remove_from_gcp(images.fetch('gcp', []))
      remove_from_ecr(images.fetch('aws', []))
      remove_from_artifactory(artifactory_builds)
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
    
    # TODO: (efries) Delete me once all artifactory pushes contain an images.yaml file
    # Method to search the tar.gz files for image_tags and build versions to be used
    # to link aws/gcp/artifactory builds when no images.yaml file is present
    def search_all_the_files(files, build_path)
      images = Hash[REGISTRIES.map {|source, values| [source, []]}]
      sources_with_images = Set.new([])
      # List of repositories to check for images of in tar.gz files on artifactory
      repos = ['toolbox', 'tracectl', 'backfills', 'gcloud', 'cfs-sync']
    
      files.each do |file|
        if file.end_with? '.tar.gz'
          fetch_url = "#{ARTIFACTORY_HOST}/#{build_path}/#{file}"
    
          gzip_reader = nil
          begin
            # Using open-uri reads
            source = open(fetch_url)
            gzip_reader = Zlib::GzipReader.new(source)
          rescue OpenURI::HTTPError => e
            Logger.error("Error in reading file #{fetch_url}: #{e.message}")
            next
          end
    
          # Returns as a string of all the files with their content
          contents = gzip_reader.read
    
          PREFIX_TO_REGISTRY.each do |prefix, source|
    
            # !!! This match is ONLY for arbor_master !!!
            # Each repo might need it's own customization
            # The reason we are searching for cfs-sync is since it is in the tar.gz
            # files upon publishing of the container
            matches = contents.scan(/#{prefix}\/cfs-sync:[\w-].+?(?=[,\"])/)
    
            # Workaround to add values in for the images of repositories that are not
            # found in the tar.gz files. The tagged version of cfs-sync will be the same
            # across multiple repositories. This workaround allows us to populate a list of
            # images to delete when they are not found in the tar.gz files OR there is no images.yaml
            if not matches.empty?
              # Image tags are of the form <prefix>/<repo>:<image_tag>
              version = matches[0].split(':').last
              repos.each do |repo|
                matches.push("#{prefix}/#{repo}:#{version}")
              end
              sources_with_images.add(prefix)
            end
            images[source].push(*matches.to_set)
          end
         end
        end
    
      # This case here covers when there are images found for at least one but not all
      # image keys.
      missing_images = images.keys.to_set - sources_with_images
      if not missing_images.empty? and missing_images.size < images.size
        images.keys.each do |source|
          if sources_with_images.include?(source)
            next
          end
    
          images_exist_source = sources_with_images.to_a[0] # Get one of the main images to copy over
          created_images = []
          images[images_exist_source].each do |existing|
            created = existing.sub(REGISTRIES[images_exist_source]['prefix'], REGISTRIES[source]['prefix'])
            created_images.push(created)
          end
    
          images[source].push(*created_images)
        end
      end
    
      remove_from_ecr(images.fetch('aws', []))
      remove_from_gcp(images.fetch('gcp', []))
    end
  end
end
