require 'fileutils'

require 'kube_deploy_tools/shellrunner'
require 'kube_deploy_tools/built_artifacts_file'
require 'kube_deploy_tools/deploy_config_file'

require 'kube_deploy_tools/image_registry/driver'
require 'kube_deploy_tools/image_registry/image'

BUILT_ARTIFACTS_FILE = 'build/kubernetes/images.yaml'.freeze

module KubeDeployTools
  class PublishContainer
    def initialize(config, local_prefix, registries, images, tag)
      @config = config
      @local_prefix = local_prefix

      # If |registries| is empty, assume we will push them all,
      # if not, subtract unwanted ones from |config.image_registries|
      if registries.empty?
        to_instantiate = config.image_registries.values
      else
        to_instantiate = []
        config.image_registries.each do |name, registry|
          if registries.member? name
            to_instantiate.push registry
          end
        end
      end

      @drivers = to_instantiate.map do |registry|
        driver_class = ImageRegistry::Driver::MAPPINGS.fetch(registry.driver)
        [registry, driver_class.new(registry: registry)]
      end.to_h
      @base_image_names = images
      @tag = tag
    end

    def publish
      dirname = File.dirname(BUILT_ARTIFACTS_FILE)
      FileUtils.mkdir_p(dirname)

      driver_images = []

      @drivers.each_pair do |registry, driver|
        driver_images.unshift [driver, tag_images(registry, @base_image_names)]
        # Does whatever is necessary to authorize against this registry
        driver.authorize
      end

      # Push first images to each registry in parallel
      driver_images.map do |driver, all_images|
        Thread.new { driver.push_image all_images[0] }
      end.each(&:join)

      # Push the rest of the images to each registry in parallel
      driver_images.map do |driver, all_images|
        _, *remaining_images = all_images
        remaining_images.map do |i|
          Thread.new { driver.push_image i }
        end
      end.flatten.each(&:join)

      # Can't lock the file if it doesn't exist. Create the file as a
      # placeholder until more content is loaded
      File.open(BUILT_ARTIFACTS_FILE, File::CREAT|File::RDWR) do |file|
        flock(file, File::LOCK_EX) do |file|
          driver_images.each do |_, all_images|
            update_built_artifacts(all_images, file)
          end
        end
      end

    # Clean registry authorization in the end no matter what
    ensure
      Logger.info "Removing registry authorizations"
      @drivers.each_pair do |registry, driver|
        driver.unauthorize
      end
    end

    private

    def tag_images(r, base_image_names)
      base_image_names.map do |i|
        local = Image.new(@local_prefix, i, 'latest')
        remote = Image.new(r.prefix, i, @tag)
        Shellrunner.check_call('docker', 'tag', local.full_tag, remote.full_tag)
        remote
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
