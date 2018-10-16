require 'pathname'
require 'set'
require 'yaml'

require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/image_registry'

DEPLOY_YAML = 'deploy.yaml'
DEPLOY_YML_V1 = 'deploy.yml'

module KubeDeployTools
  # Read-only model for the deploy.yaml configuration file.
  class DeployConfigFile
    attr_accessor :artifacts, :default_flags, :flavors, :hooks, :image_registries, :sweeper

    def initialize(filename)
      config = nil
      if !filename.nil? && Pathname.new(filename).absolute?
        config = YAML.load_file(filename)
      else
        original_dir = Dir.pwd
        changed_dir = false
        until Dir.pwd == '/'
          # Try looking for filename specified by user.
          # If no filename was specified by the user, then look for
          # deploy.yml or deploy.yaml.
          if !filename.nil? && File.exist?(filename)
            config = YAML.load_file(filename)
            break
          elsif filename.nil? && File.exist?(DEPLOY_YAML)
            filename = DEPLOY_YAML
            config = YAML.load_file(filename)
            break
          elsif filename.nil? && File.exist?(DEPLOY_YML_V1)
            Logger.warn('Found deprecated v1 deploy.yml. Please run `kdt upgrade` to v2 deploy.yaml')
            filename = DEPLOY_YML_V1
            config = YAML.load_file(filename)
            break
          end

          # KDT should run in the directory containing the deploy config file.
          changed_dir = true
          Dir.chdir('..')
        end
        if config.nil?
          Dir.chdir(original_dir)
          raise "Could not locate file: #{filename} in any directory"
        end
        if changed_dir
          Logger.warn "Changed directory to #{Dir.pwd} (location of #{filename})"
        end
      end
      @filename = filename
      @original_config = config

      version = config.fetch('version', 1)
      check_and_warn(
        config.has_key?('version'),
        'Expected .version to be specified, but .version is missing. Falling back to version 1 config schema')
      check_and_err([1, 2].include?(version), "Expected valid version, but received unsupported version '#{version}'")

      case version
      when 2
        fetch_and_parse_version2_config!
      when 1
        fetch_and_parse_version1_config!
      end
    end

    def fetch_and_parse_version2_config!
      config = @original_config
      @image_registries = parse_image_registries(config.fetch('image_registries', []))
      @default_flags = parse_default_flags(config.fetch('default_flags', {}))
      @artifacts = parse_artifacts(config.fetch('artifacts', []))
      @flavors = parse_flavors(config.fetch('flavors', {}))
      @hooks = parse_hooks(config.fetch('hooks', ['default']))
      @sweeper = parse_sweeper(config.fetch('sweeper', []))
    end

    # Fetches and parse a version 1 config as a version 2 config, with the
    # defaults set as previously with KDT 1.x behavior
    def fetch_and_parse_version1_config!
      config = @original_config
      @image_registries = parse_image_registries([
        {
          'name' => 'aws',
          'driver' => 'aws',
          'prefix' => '***REMOVED***',
          'config' => {
            'region' => 'us-west-2'
          }
        },
        {
          'name' => 'gcp',
          'driver' => 'gcp',
          'prefix' => '***REMOVED***'
        }
      ])
      @default_flags = parse_default_flags({
        'pull_policy' => 'IfNotPresent',
      })
      @artifacts = parse_artifacts(config.fetch('deploy').fetch('clusters', [])
        .map.with_index { |c, i|
          target = c.fetch('target')
          environment = c.fetch('environment')
          case target
          when 'local'
            cloud = 'local'
            image_registry = 'local-registry'
          when 'colo-service'
            cloud = 'colo'
            image_registry = '***REMOVED***'
          when 'us-east-1', 'us-west-2', 'eu-west-1'
            cloud = 'aws'
            image_registry = '***REMOVED***'
          when 'gcp'
            cloud = 'gcp'
            image_registry = '***REMOVED***'
          else
            raise ArgumentError, "Expected a valid KDT 1.x .target for .deploy.clusters[#{i}].target, but got '#{target}'"
          end

          flags = c.fetch('extra_flags', {})
            .merge({
              'target' => target,
              'environment' => environment,
              'cloud' => cloud,
              'image_registry' => image_registry,
            })

          if flags.key?('pull_policy') && flags.fetch('pull_policy') == @default_flags.fetch('pull_policy')
            flags.delete('pull_policy')
          end

          artifact = {
            'name' => target + '-' + environment,
            'flags' => flags,
          }

          artifact
        }
      )
      @flavors = parse_flavors(config.fetch('deploy', {}).fetch('flavors', {}))
      @hooks = parse_hooks(config.fetch('deploy', {}).fetch('hooks', ['default']))
    end

    def parse_image_registries(image_registries)
      check_and_err(image_registries.is_a?(Array), '.image_registries is not an Array')
      image_registries = image_registries.map { |i| ImageRegistry.new(i) }

      # Validate that only one instance of each driver is registered
      duplicates = select_duplicates(image_registries.map { |i| i.name })
      check_and_err(
        duplicates.count == 0,
        "Expected .image_registries names to be unique, but found duplicates: #{duplicates}"
      )

      image_registries
        .map { |i| [i.name, i] }
        .to_h
    end

    def parse_artifacts(artifacts)
      check_and_err(artifacts.is_a?(Array), '.artifacts is not an Array')

      duplicates = select_duplicates(artifacts.map { |i| i.fetch('name') })
      check_and_err(
        duplicates.count == 0,
        "Expected .artifacts names to be unique, but found duplicates: #{duplicates}"
      )

      artifacts.each { |artifact, index|
        check_and_err(
          artifact.key?('name'),
          "Expected .artifacts[#{index}].name key to exist, but .name is missing"
        )
        name = artifact.fetch('name')

        check_and_err(
          artifact.key?('flags'),
          "Expected .artifacts.#{name}.flags key to exist, but .flags is missing"
        )
      }
    end

    def parse_default_flags(default_flags)
      check_and_err(default_flags.is_a?(Hash), '.default_flags is not a Hash')

      default_flags
    end

    def parse_flavors(flavors)
      check_and_err(flavors.is_a?(Hash), '.flavors is not a Hash')

      flavors
    end

    def parse_hooks(hooks)
      check_and_err(hooks.is_a?(Array), '.hooks is not an Array')

      hooks
    end

    def parse_sweeper(sweeper)
      check_and_err(sweeper.is_a?(Array), '.sweeper is not an Array')

      sweeper
    end

    # upgrade! converts the config to a YAML string in the format
    # of the latest supported version
    # e.g. with the latest supported version as v2,
    # to_yaml will always print a valid v2 YAML
    def upgrade!
      version = @original_config.fetch('version', 1)
      case version
      when 2
        config = @original_config
      when 1
        Logger.info('Upgrading v1 deploy.yml to v2 deploy.yaml')
        config = {
          'version' => 2,
          'artifacts' => @artifacts.map { |a|
            {
              'name' => a.fetch('name'),
              'flags' => a.fetch('flags', {})
            }
          },
          'flavors' => @flavors,
          'default_flags' => @default_flags,
          'hooks' => @hooks,
        }
      end

      File.open(@filename, 'w+') { |file| file.write(config.to_yaml) }

      # Rename deploy.yml to deploy.yaml, if necessary
      dirname  = File.dirname(@filename)
      basename = File.basename(@filename)
      if basename == DEPLOY_YML_V1
        Logger.info('Renaming deploy.yml => deploy.yaml')
        File.rename(@filename, "#{dirname}/#{DEPLOY_YAML}")
      end
    end

    def select_duplicates(array)
      array.select { |n| array.count(n) > 1 }.uniq
    end

    def check_and_err(condition, error)
      if ! condition
        Logger.error("Error in configuration #{@filename}")
        raise ArgumentError, error
      end
    end

    def check_and_warn(condition, warning)
      if ! condition
        Logger.warn("Warning in configuration #{@filename}")
        Logger.warn(warning)
      end
    end
  end
end
