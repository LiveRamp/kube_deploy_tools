module KubeDeployTools
  # Read-only model for image_registries[] array element in KDT deploy.yaml
  # configuration file.
  class ImageRegistry
    attr_accessor :name, :driver, :prefix, :config

    def initialize(h)
      @name = h['name']
      @driver = h['driver']
      @prefix = h['prefix']
      @config = h['config']
    end

    def ==(o)
      @name == o.name
      @driver == o.driver
      @prefix == o.prefix
      @config == o.config
    end
  end
end
