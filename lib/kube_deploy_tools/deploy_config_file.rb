require 'pathname'
require 'set'
require 'yaml'

require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/image_registry'

module KubeDeployTools
  # Read-only model for the deploy.yaml configuration file.
  class DeployConfigFile
    # TODO(joshk): Plug |deploys|, |artifacts| into this model.
    # TODO(joshk): Implement backwards compatibility support into this model.
    attr_accessor :default_flags, :image_registries

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

      @image_registries = Hash[reg_pairs]
      @default_flags = config.fetch('default_flags', {})
      # Basic type checking
      raise 'default_flags is not a Hash' unless @default_flags.is_a?(Hash)
    end
  end
end
