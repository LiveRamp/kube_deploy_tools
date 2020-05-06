require 'kube_deploy_tools/artifact_registry/driver'
require 'kube_deploy_tools/formatted_logger'

module KubeDeployTools
  # Read-only model for artifact_registries[] array element in KDT deploy.yaml
  # configuration file.
  class ArtifactRegistry
    attr_accessor :name, :driver_name, :config, :driver

    def initialize(h)
      @name = h['name']
      @driver_name = h['driver']
      @config = h['config']

      if !ArtifactRegistry::Driver::MAPPINGS.key?(@driver_name)
        Logger.warn("Unsupported .artifact_registries.driver: #{@driver_name}")
      else
        @driver = ArtifactRegistry::Driver::MAPPINGS
          .fetch(@driver_name)
          .new(config: @config)
      end
    end

    def ==(o)
      @name == o.name
      @driver == o.driver
      @prefix == o.prefix
      @config == o.config
    end
  end
end
