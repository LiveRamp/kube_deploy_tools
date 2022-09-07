require 'uri'
require 'yaml'

require 'kube_deploy_tools/built_artifacts_file'
require 'kube_deploy_tools/deploy_config_file'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/object'

module KubeDeployTools
  class Publish
    def initialize(manifest:, artifact_registry:, output_dir:)
      @config = DeployConfigFile.new(manifest)
      @output_dir = output_dir

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
          @artifact_registry.upload(
            local_dir: @output_dir,
            name: name,
            flavor: flavor,
            project: @project,
            build_number: @build_number,
          )
        end
      end
    end
  end
end
