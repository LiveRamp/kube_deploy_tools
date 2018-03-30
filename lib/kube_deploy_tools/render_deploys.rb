require 'erb'
require 'fileutils'
require 'tempfile'
require 'time'
require 'yaml'

require 'kube_deploy_tools/render_deploys_hook'
require 'kube_deploy_tools/deploy_artifact'
require 'kube_deploy_tools/cluster_config'
require 'kube_deploy_tools/shellrunner'

DEFAULT_HOOK_SCRIPT = 'render_deploys_hook'
DEFAULT_HOOK_SCRIPT_LABEL = 'default'

module KubeDeployTools
  DEFAULT_FLAGS = {
    'image_tag' => tag_from_local_env,
    'tag' => tag_from_local_env,
    'image_registry' => DEFAULT_REGISTRY,
  }.freeze
  class RenderDeploys
    def initialize(manifest, input_dir, output_dir)

      unless File.file?(manifest)
        raise "Can't read deploy manifest: #{manifest}"
      end

      @project = KubeDeployTools::PROJECT
      @build_number = KubeDeployTools::BUILD_NUMBER

      @input_dir = input_dir
      @output_dir = output_dir
      FileUtils.mkdir_p @output_dir

      @manifest = YAML.load(File.read(manifest)).fetch('deploy')
    end

    def render
      clusters = @manifest.fetch('clusters')
      flavors = @manifest.fetch('flavors')

      # Sanity check.
      unless clusters.size > 0
        raise 'Must support deployment to at least one cluster'
      end

      unless flavors.size > 0
        raise 'Must support at least one flavor (try "_default": {})'
      end

      hooks = @manifest['hooks'] || [DEFAULT_HOOK_SCRIPT_LABEL]
      pids = {}
      clusters.each do |c|
        target = c.fetch('target')
        env = c.fetch('environment')

        # Get metadata for this target/environment pair.
        cluster = CLUSTERS.fetch(target).fetch(env)
        cluster_flags = DEFAULT_FLAGS.dup

        cluster_flags.update('target' => target, 'environment' => env)
        cluster_flags.merge!(render_erb_flags(cluster['flags']))
        cluster_flags.merge!(render_erb_flags(c['extra_flags'])) if c['extra_flags']

        # Allow deploy.yml to gate certain flavors to certain targets.
        cluster_flavors = flavors.reject { |key, value| !(c['flavors'].nil? or c['flavors'].include? key) }
        cluster_flavors.each do |flavor, flavor_flags|
          full_flags = cluster_flags.clone
          full_flags.merge!(render_erb_flags(flavor_flags)) if flavor_flags

          # Call individual templating hook with the rendered configuration
          # and a prefix to place all the files. Run many hooks in the
          # background.
          flavor_dir = File.join(@output_dir, target, env, flavor)
          FileUtils.rm_rf flavor_dir
          FileUtils.mkdir_p flavor_dir

          puts "*** rendering configuration: #{target}_#{env}_#{flavor}"
          pid = fork do
            # Save rendered release configuration to a temp file.
            rendered = Tempfile.new('deploy_config')
            rendered << YAML.dump(full_flags)
            rendered.flush

            # Run every hook sequentially. 'default' hook is special.
            hooks.each do |hook|
              if hook == DEFAULT_HOOK_SCRIPT_LABEL
                # TODO(joshk): render_deploys method should take a hash for testability
                KubeDeployTools::RenderDeploysHook.render_deploys(rendered.path, @input_dir, flavor_dir)
              else
                Shellrunner.check_call(hook, rendered.path, @input_dir, flavor_dir)
              end
            end

            # Pack up contents of each flavor_dir to a correctly named artifact tarball.
            tarball = KubeDeployTools.build_deploy_artifact_name(project: @project, build_number: @build_number, target: target, environment: env, flavor: flavor)
            tarball_full_path = File.join(@output_dir, tarball)
            Shellrunner.check_call('tar', '-C', flavor_dir, '-czf', tarball_full_path, '.')
            puts "*** generated manifest archive: #{tarball_full_path}"
          end

          pids[pid] = "#{target}_#{env}_#{flavor}"
        end
      end

      failure = false
      Process.waitall.each do |pid, status|
        if status.exitstatus != 0
          puts "!!! rendering #{pids[pid]} failed: exit status #{status.exitstatus}"
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
  end
end
