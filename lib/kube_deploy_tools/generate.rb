require 'erb'
require 'fileutils'
require 'tempfile'
require 'time'
require 'yaml'

require 'kube_deploy_tools/render_deploys_hook'
require 'kube_deploy_tools/deploy_config_file'
require 'kube_deploy_tools/file_filter'
require 'kube_deploy_tools/shellrunner'
require 'kube_deploy_tools/tag'

DEFAULT_HOOK_SCRIPT = 'render_deploys_hook'
DEFAULT_HOOK_SCRIPT_LABEL = 'default'

module KubeDeployTools
  DEFAULT_FLAGS = {
    'image_tag' => tag_from_local_env,
    'tag' => tag_from_local_env,
  }.freeze
  class Generate
    def initialize(manifest, input_dir, output_dir, file_filters: [], print_flags_only: false, literals: {})
      @project = KubeDeployTools::PROJECT
      @build_number = KubeDeployTools::BUILD_NUMBER

      @config = DeployConfigFile.new(manifest)
      @literals = literals

      @input_dir = input_dir
      @output_dir = output_dir
      FileUtils.mkdir_p @output_dir

      @file_filters = file_filters

      @print_flags_only = print_flags_only
    end

    def git_commit
      commit_sha = Shellrunner.check_call(*%w(git rev-parse HEAD))
      commit_sha ? commit_sha.strip : ''
    end

    def git_project
      project_url = Shellrunner.check_call(*%w(git config --get remote.origin.url))
      project_url ? project_url.strip : ''
    end

    def generate
      permutations = {}
      @config.artifacts.each do |c|
        artifact = c.fetch('name')

        # Get metadata for this target/environment pair from manifest
        cluster_flags = DEFAULT_FLAGS.dup

        cluster_flags['image_registry'] = c.fetch('image_registry')

        # Merge in configured default flags
        cluster_flags.merge!(@config.default_flags)

        # Update and merge deploy flags for rendering
        cluster_flags.merge!(generate_erb_flags(c.fetch('flags', {})))

        cluster_flags['image_registry'] = @config.valid_image_registries[cluster_flags['image_registry']]
        # Allow deploy.yaml to gate certain flavors to certain targets.
        cluster_flavors = @config.flavors.select { |key, value| c['flavors'].nil? || c['flavors'].include?(key) }
        cluster_flavors.each do |flavor, flavor_flags|
          full_flags = cluster_flags.clone
          full_flags.merge!(generate_erb_flags(flavor_flags)) if flavor_flags
          # Project information used to identify source of various manifests
          full_flags.merge!({
            'git_commit' => git_commit,
            'git_project' => git_project
          })

          full_flags.merge!(@literals)

          # Print all flags for each artifact-flavor
          puts "artifact '#{artifact}', flavor '#{flavor}'"
          full_flags.
            sort_by { |k, v| k }.
            each do |k, v|
              puts "config['#{k}'] = #{v}"
            end
          puts ""
          # Skip rendering ERB templates and generating artifacts
          # if printing flags only
          next if @print_flags_only

          file_filters = FileFilter.filters_from_hash(c) + @file_filters

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
            @config.hooks.each do |hook|
              if hook == DEFAULT_HOOK_SCRIPT_LABEL
                # TODO(joshk): render_deploys method should take a hash for testability
                KubeDeployTools::RenderDeploysHook.render_deploys(rendered.path, @input_dir, flavor_dir, file_filters)
              else
                Shellrunner.check_call(hook, rendered.path, @input_dir, flavor_dir)
              end
            end
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

    def generate_erb_flags(flags)
      result = Hash.new

      flags.each do |key, template|
        if template.is_a?(String)
          templater = ERB.new(template)
          result[key] = templater.result
        else
          result[key] = template
        end
      end

      result
    end
  end
end
