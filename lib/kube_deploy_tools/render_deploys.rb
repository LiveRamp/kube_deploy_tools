require 'erb'
require 'fileutils'
require 'tempfile'
require 'time'
require 'yaml'

require 'kube_deploy_tools/render_deploys_hook'
require 'kube_deploy_tools/deploy_artifact'
require 'kube_deploy_tools/deploy_config_file'
require 'kube_deploy_tools/shellrunner'
require 'kube_deploy_tools/tag'

DEFAULT_HOOK_SCRIPT = 'render_deploys_hook'
DEFAULT_HOOK_SCRIPT_LABEL = 'default'

module KubeDeployTools
  DEFAULT_FLAGS = {
    'image_tag' => tag_from_local_env,
    'tag' => tag_from_local_env,
  }.freeze
  class RenderDeploys
    def initialize(manifest, input_dir, output_dir, file_filters = [])

      unless File.file?(manifest)
        raise "Can't read deploy manifest: #{manifest}"
      end

      @project = KubeDeployTools::PROJECT
      @build_number = KubeDeployTools::BUILD_NUMBER

      @input_dir = input_dir
      @output_dir = output_dir
      FileUtils.mkdir_p @output_dir

      @config = DeployConfigFile.new(manifest)
      # TODO(joshk): Get rid of this version and use only DeployConfigFile instance
      @manifest = YAML.load_file(manifest)
      validate_manifest

      @file_filters = file_filters
    end

    def render
      artifacts = @manifest.fetch('artifacts')
      flavors = @manifest.fetch('flavors')

      hooks = @manifest['hooks'] || [DEFAULT_HOOK_SCRIPT_LABEL]
      permutations = {}
      artifacts.each do |c|
        artifact = c.fetch('name')

        # Get metadata for this target/environment pair from manifest
        cluster_flags = DEFAULT_FLAGS.dup
        # Merge in configured default flags
        cluster_flags.merge!(@config.default_flags)

        # Update and merge deploy flags for rendering
        cluster_flags.merge!(render_erb_flags(c.fetch('flags', {})))

        # Allow deploy.yml to gate certain flavors to certain targets.
        cluster_flavors = flavors.reject { |key, value| !(c['flavors'].nil? or c['flavors'].include? key) }
        cluster_flavors.each do |flavor, flavor_flags|
          full_flags = cluster_flags.clone
          full_flags.merge!(render_erb_flags(flavor_flags)) if flavor_flags

          # Call individual templating hook with the rendered configuration
          # and a prefix to place all the files. Run many hooks in the
          # background.
          flavor_dir = File.join(@output_dir, "#{artifact}_#{flavor}")
          FileUtils.rm_rf flavor_dir
          FileUtils.mkdir_p flavor_dir
          pid = fork do
            # Save rendered release configuration to a temp file.
            rendered = Tempfile.new('deploy_config')
            rendered << YAML.dump(full_flags)
            rendered.flush

            # Run every hook sequentially. 'default' hook is special.
            hooks.each do |hook|
              if hook == DEFAULT_HOOK_SCRIPT_LABEL
                # TODO(joshk): render_deploys method should take a hash for testability
                KubeDeployTools::RenderDeploysHook.render_deploys(rendered.path, @input_dir, flavor_dir, @file_filters)
              else
                Shellrunner.check_call(hook, rendered.path, @input_dir, flavor_dir)
              end
            end

            # Pack up contents of each flavor_dir to a correctly named artifact tarball.
            tarball = KubeDeployTools.build_deploy_artifact_name(name: artifact, flavor: flavor)
            tarball_full_path = File.join(@output_dir, tarball)
            Shellrunner.check_call('tar', '-C', flavor_dir, '-czf', tarball_full_path, '.')
          end

          permutations[pid] = "#{artifact}_#{flavor}"
        end
      end

      failure = false
      Process.waitall.each do |pid, status|
        if status.exitstatus != 0
          Logger.error "Rendering #{permutations[pid]} failed: exit status #{status.exitstatus}"
          failure = true
        end
      end

      raise 'rendering deploy configurations failed' if failure
    end

    def render_erb_flags(flags)
      result = Hash.new

      flags.each do |key, template|
        if template.is_a?(String)
          renderer = ERB.new(template)
          result[key] = renderer.result
        else
          result[key] = template
        end
      end

      result
    end

    def validate_manifest
      artifacts = @manifest.fetch('artifacts')
      flavors = @manifest.fetch('flavors')

      unless artifacts.size > 0
        raise 'Must support deployment to at least one artifact'
      end

      unless flavors.size > 0
        raise 'Must support at least one flavor (try "_default": {})'
      end
    end
  end
end
