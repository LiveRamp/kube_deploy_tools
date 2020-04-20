require 'uri'
require 'yaml'

require 'kube_deploy_tools/built_artifacts_file'
require 'kube_deploy_tools/deploy_config_file'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/object'

module KubeDeployTools
  class Publish
    def initialize(manifest:, artifact_registry:, output_dir:, extra_files:)
      @config = DeployConfigFile.new(manifest)
      @output_dir = output_dir
      @extra_files = extra_files

      @project = KubeDeployTools::PROJECT
      @build_number = KubeDeployTools::BUILD_NUMBER

      @artifact_registry = artifact_registry.driver
    end

    def publish()
      @config.artifacts.each do |c|
        name = c.fetch('name')

        # Allow deploy.yaml to gate certain flavors to certain targets.
        cluster_flavors = @config.flavors.select { |key, value| c['flavors'].nil? || c['flavors'].include?(key) }

        cluster_flavors.each do |flavor, _|

          local_artifact_path = @artifact_registry.get_local_artifact_path(
            local_dir: @output_dir,
            name: name,
            flavor: flavor,
          )

          registry_artifact_path = @artifact_registry.get_registry_artifact_path(
            project: @project,
            name: name,
            flavor: flavor,
            build_number: @build_number,
          )

          @artifact_registry.publish(
            local_artifact_path: local_artifact_path,
            registry_artifact_path: registry_artifact_path,
          )
        end
      end

      images_yaml = File.join(@output_dir, 'images.yaml')

      @extra_files.each do |f|
        base = File.basename(f)
        @artifact_registry.publish(
          local_artifact_path: f,
          registry_artifact_path: "#{@project}/#{@build_number}/#{base}",
        )

        manifest = KubeDeployTools::BuiltArtifactsFile.new(images_yaml)
        manifest.extra_files.add base

        Logger.info("Registered #{f} as extra artifact of the build")
      end

      @artifact_registry.publish(
        local_artifact_path: images_yaml,
        registry_artifact_path: "#{@project}/#{@build_number}/images.yaml",
      )
    end
  end
end
