require 'pathname'
require 'set'
require 'yaml'

require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/image_registry'

module KubeDeployTools
  # Read-only model for the deploy.yaml configuration file.
  class DeployConfigFile
    attr_accessor :artifacts, :default_flags, :flavors, :hooks, :image_registries

    def initialize(filename = 'deploy.yml')
      config = nil
      if Pathname.new(filename).absolute?
        config = YAML.load_file(filename)
      else
        changed_dir = false
        until Dir.pwd == '/'
          if File.exist? filename
            config = YAML.load_file(filename)
            break
          end

          # KDT should run in the directory containing the deploy config file.
          changed_dir = true
          Dir.chdir('..')
        end
        raise "Could not locate file: #{filename} in any directory" if config.nil?
        if changed_dir
          Logger.warn "Changed directory to #{Dir.pwd} (location of #{filename})"
        end
      end

      # TODO(joshk): Validate that only one instance of each driver is registered.
      reg_pairs = config.fetch('image_registries', []).map do |data|
        reg = ImageRegistry.new(data)
        [reg.name, reg]
      end

      # TODO(joshk): Implement backwards compatibility support into this model?
      @image_registries = Hash[reg_pairs]
      @artifacts = config.fetch('artifacts', [])
      @default_flags = config.fetch('default_flags', {})
      @flavors = config.fetch('flavors', {})
      @hooks = config.fetch('hooks', ['default'])

      # Basic type checking
      raise 'artifacts is not an Array' unless @artifacts.is_a?(Array)
      raise 'default_flags is not a Hash' unless @default_flags.is_a?(Hash)
      raise 'flavors is not a Hash' unless @flavors.is_a?(Hash)
      raise 'hooks is not an Array' unless @hooks.is_a?(Array)
    end

    def validate!
      unless @artifacts.size > 0
        raise 'Must support deployment to at least one artifact'
      end

      unless @flavors.size > 0
        raise 'Must support at least one flavor (try "_default": {})'
      end
    end
  end
end
