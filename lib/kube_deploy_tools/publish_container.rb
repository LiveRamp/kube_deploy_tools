require 'fileutils'

require 'kube_deploy_tools/cluster_config'
require 'kube_deploy_tools/shellrunner'
require 'kube_deploy_tools/built_artifacts_file'

require 'kube_deploy_tools/publish_container/image'
require 'kube_deploy_tools/publish_container/driver'

BUILT_ARTIFACTS_FILE = 'build/kubernetes/images.yaml'.freeze

module KubeDeployTools
  class PublishContainer
    def initialize(local_prefix, registry_name, images, tag)
      @local_prefix = local_prefix
      @registry = REGISTRIES[registry_name]
      @base_image_names = images
      @tag = tag

      if (driver_class = Driver::MAPPINGS[@registry['driver']])
        @registry_driver = driver_class.new(registry: @registry)
      else
        raise "No driver exists for registry type #{@registry['driver']}"
      end
    end

    def publish
      images_to_push = tag_images(@base_image_names)

      # Does whatever is necessary to authorize against this registry
      @registry_driver.authorize
      push_images(images_to_push)

      # Can't lock the file if it doesn't exist. Create the file as a
      # placeholder until more content is loaded
      dirname = File.dirname(BUILT_ARTIFACTS_FILE)
      FileUtils.mkdir_p(dirname)
      File.open(BUILT_ARTIFACTS_FILE, File::CREAT|File::RDWR) do |file|
        flock(file, File::LOCK_EX) do |file|
          update_built_artifacts(images_to_push, file)
        end
      end
    end

    private

    def tag_images(base_image_names)
      base_image_names.map do |i|
        local = Image.new(@local_prefix, i, 'latest')
        remote = Image.new(@registry['prefix'], i, @tag)
        Shellrunner.check_call('docker', 'tag', local.full_tag, remote.full_tag)
        remote
      end
    end

    def push_images(all_images)
      # Split a list into head and tail (car, cdr)
      first_image, *remaining_images = *all_images

      # Push a single container under the assumption that
      # most containers in this pass are built on a similar image.
      @registry_driver.push_image(first_image)

      # Push the rest of the containers in parallel
      remaining_images.each do |i|
        Thread.new { @registry_driver.push_image i }.join
      end
    end

    def update_built_artifacts(images_to_push, file)
      artifacts = KubeDeployTools::BuiltArtifactsFile.new(file)
      build_id = ENV.fetch('BUILD_ID', 'LOCAL')

      if !artifacts.build_id.nil? && artifacts.build_id != build_id
        # Clear the images as this is a fresh build.
        artifacts.images = Set.new
        # Truncate the file so it will generate a new file
        # and remove any old builds
        file.truncate(0)
      end

      # Add new images to the output list.
      artifacts.build_id = build_id
      images_to_push.each do |image|
        artifacts.images.add image.full_tag
      end

      # Write the config list.
      artifacts.write file
    end

    # Method used to protect reads and writes. From:
    # https://www.safaribooksonline.com/library/view/ruby-cookbook/0596523696/ch06s13.html
    def flock(file, mode)
      success = file.flock(mode)
      if success
        begin
          yield file
        ensure
          file.flock(File::LOCK_UN)
        end
      end
      return success
    end
  end
end
