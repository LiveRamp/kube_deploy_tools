require 'pathname'
require 'set'
require 'yaml'

require 'kube_deploy_tools/deploy_config_file/util'
require 'kube_deploy_tools/deploy_config_file/deep_merge'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/image_registry'
require 'kube_deploy_tools/shellrunner'
require 'kube_deploy_tools/artifact_registry'

DEPLOY_YAML = 'deploy.yaml'

module KubeDeployTools
  PROJECT = ENV['JOB_NAME'] || File.basename(`git config remote.origin.url`.chomp, '.git')
  BUILD_NUMBER = ENV.fetch('BUILD_ID', 'dev')

  # Read-only model for the deploy.yaml configuration file.
  class DeployConfigFile
    attr_accessor :artifacts, :default_flags, :flavors, :hooks, :image_registries, :valid_image_registries, :expiration, :artifact_registries, :artifact_registry

    include DeployConfigFileUtil

    # TODO(joshk): Refactor into initialize(fp) which takes a file-like object;
    # after this, auto discovery should go into DeployConfigFile.locate
    # classmethod.  This would require erasing auto-upgrade capability, which
    # should be possible if we major version bump.
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
          end

          # KDT should run in the directory containing the deploy config file.
          changed_dir = true
          Dir.chdir('..')
        end
        if config.nil?
          Dir.chdir(original_dir)
          if ! filename.nil?
            raise "Could not locate file: config file '#{filename}' in any directory"
          else
            raise "Could not locate file: config file '#{DEPLOY_YAML}' in any directory"
          end
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
      else
        raise "Unsupported version #{version}"
      end
    end

    def fetch_and_parse_version2_config!
      # The literal contents of your deploy.yaml are now populated into |self|.
      config = @original_config
      @image_registries = parse_image_registries(config.fetch('image_registries', []))
      @default_flags = config.fetch('default_flags', {})
      @artifacts = config.fetch('artifacts', [])
      @flavors = config.fetch('flavors', {})
      @hooks = config.fetch('hooks', ['default'])
      @expiration = config.fetch('expiration', [])
      @artifact_registries = parse_artifact_registries(config.fetch('artifact_registries', []))
      @artifact_registry = parse_artifact_registry(config.fetch('artifact_registry', ''), @artifact_registries)

      validate_default_flags
      validate_flavors
      validate_hooks
      validate_expiration

      # Augment these literal contents by resolving all libraries.
      # extend! typically gives the current file precedence when merge conflicts occur,
      # but the expected precedence of library inclusion is the reverse (library 2 should
      # overwrite what library 1 specifies), so reverse the libraries list first.
      config.fetch('libraries', []).reverse.each do |libfn|
        extend!(load_library(libfn))
      end

      # Now that we have a complete list of image registries, validation is now possible.
      # Note that this also populates @valid_image_registries.
      validate_artifacts!
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

    def map_image_registry(image_registries)
      valid_image_registries = {}
      image_registries.each do |reg_name, reg_info|
        valid_image_registries[reg_name] = reg_info.prefix
      end
      valid_image_registries
    end

    # .artifacts depends on .default_flags and .image_registries
    def validate_artifacts!
      check_and_err(artifacts.is_a?(Array), '.artifacts is not an Array')

      duplicates = select_duplicates(artifacts.map { |i| i.fetch('name') })
      check_and_err(
        duplicates.count == 0,
        "Expected .artifacts names to be unique, but found duplicates: #{duplicates}"
      )

      @valid_image_registries = map_image_registry(@image_registries)

      artifacts.each_with_index { |artifact, index|
        check_and_err(
          artifact.key?('name'),
          "Expected .artifacts[#{index}].name key to exist, but .name is missing"
        )
        name = artifact.fetch('name')
        check_and_err(
          artifact.key?('image_registry'),
          "Expected .artifacts[#{index}].image_registry key to exist, but .image_registry is missing"
        )

        image_registry = artifact.fetch('image_registry')
        check_and_err(
          @valid_image_registries.key?(image_registry),
          "#{image_registry} is not a valid Image Registry. Has to be one of #{@valid_image_registries.keys}"
        )

        check_and_err(
          artifact.key?('flags'),
          "Expected .artifacts.#{name}.flags key to exist, but .flags is missing"
        )
      }
    end

    def validate_default_flags
      check_and_err(@default_flags.is_a?(Hash), '.default_flags is not a Hash')
    end

    def validate_flavors
      check_and_err(@flavors.is_a?(Hash), '.flavors is not a Hash')
    end

    def validate_hooks
      check_and_err(@hooks.is_a?(Array), '.hooks is not an Array')
    end

    def validate_expiration
      check_and_err(@expiration.is_a?(Array), '.expiration is not an Array')
    end

    def parse_artifact_registries(artifact_registries)
      check_and_err(artifact_registries.is_a?(Array), '.artifact_registries is not an Array')
      artifact_registries = artifact_registries.map { |r| ArtifactRegistry.new(r) }

      # Validate that each artifact registry is named uniquely
      duplicates = select_duplicates(artifact_registries.map { |r| r.name })
      check_and_err(
        duplicates.count == 0,
        "Expected .artifact_registries names to be unique, but found duplicates: #{duplicates}"
      )

      unsupported_drivers = artifact_registries.
        select { |r| !ArtifactRegistry::Driver::MAPPINGS.key? r.driver_name }.
        map { |r| r.driver_name }
      check_and_err(
        unsupported_drivers.count == 0,
        "Expected .artifact_registries drivers to be valid, but found unsupported drivers: #{unsupported_drivers}. Must be a driver in: #{ArtifactRegistry::Driver::MAPPINGS.keys}",
      )

      artifact_registries
        .select { |r| r.driver_name == "gcs" }
        .select { |r| !r.config.has_key? "bucket" }
        .each { |r| check_and_err(false, "Expected .artifact_registries['#{r.config.name}'].config.bucket to exist, but no GCS bucket is specified") }


      artifact_registries
        .map { |r| [r.name, r] }
        .to_h
    end

    def parse_artifact_registry(artifact_registry, artifact_registries)
      check_and_err(artifact_registry.is_a?(String), '.artifact_registry is not a String')
      check_and_err(
        artifact_registry.empty? || artifact_registries.key?(artifact_registry),
        "#{artifact_registry} is not a valid Artifact Registry. Has to be one of #{artifact_registries.keys}"
      )

      artifact_registry
    end

    # upgrade! converts the config to a YAML string in the format
    # of the latest supported version
    # e.g. with the latest supported version as v2,
    # to_yaml will always print a valid v2 YAML
    def upgrade!
      version = @original_config.fetch('version', 1)
      case version
      when 2
        # TODO(joshk): Any required updates to v3 or remove this entire method
        true
      end
    end

    def select_duplicates(array)
      array.select { |n| array.count(n) > 1 }.uniq
    end

    # Extend this DeployConfigFile with another instance.
    def extend!(other)
      # Any image_registries entry in |self| should take precedence
      # over any identical key in |other|. The behavior of merge is that
      # the 'other' hash wins.
      @image_registries = other.image_registries.merge(@image_registries)

      # Same behavior as above for #default_flags.
      @default_flags = other.default_flags.merge(@default_flags)

      # artifacts should be merged by 'name'. In other words, if |self| and |other|
      # specify the same 'name' of a registry, self's config for that registry
      # should win wholesale (no merging of flags.)
      @artifacts = (@artifacts + other.artifacts).uniq { |h| h.fetch('name') }

      # Same behavior as for flags and registries, but the flags within the flavor
      # are in a Hash, so we need a deep merge.
      @flavors = other.flavors.deep_merge(@flavors)

      # A break from the preceding merging logic - Dependent hooks have to come
      # first and a given named hook can only be run once. But seriously, you
      # probably don't want to make a library that specifies hooks.
      @hooks = (other.hooks + @hooks).uniq

      @expiration = (@expiration + other.expiration).uniq { |h| h.fetch('repository') }
    end

    def to_h
      {
        'image_registries' => @image_registries.values.map(&:to_h),
        'default_flags' => @default_flags,
        'artifacts' => @artifacts,
        'flavors' => @flavors,
        'hooks' => @hooks,
        'expiration' => @expiration,
      }
    end

    def self.deep_merge(h, other)

    end
  end
end
