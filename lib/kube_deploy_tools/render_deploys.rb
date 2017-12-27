require 'erb'
require 'tempfile'
require 'time'
require 'yaml'

require 'kube_deploy_tools/deploy_artifact'
require 'kube_deploy_tools/cluster_config'

DEFAULT_HOOK_SCRIPT = 'render_deploys_hook'
DEFAULT_HOOK_SCRIPT_LABEL = 'default'

module KubeDeployTools
  class RenderDeploys
    def initialize(manifest, input_dir, output_dir, shellrunner:)
      @shellrunner = shellrunner

      unless File.file?(manifest)
        raise "Can't read deploy manifest: #{manifest}"
      end

      @project = ENV['JOB_NAME'] || File.basename(`git config remote.origin.url`.chomp, '.git')
      @build_number = ENV['BUILD_ID'] || DateTime.now.strftime('%Y%m%d%H%M%S')

      @input_dir = input_dir
      @output_dir = output_dir
      FileUtils.rm_rf @output_dir
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
                @shellrunner.check_call('bundle', 'exec', DEFAULT_HOOK_SCRIPT, rendered.path, @input_dir, flavor_dir)
              else
                @shellrunner.check_call(hook, rendered.path, @input_dir, flavor_dir)
              end
            end

            # Pack up contents of each flavor_dir to a correctly named artifact tarball.
            tarball = KubeDeployTools.build_deploy_artifact_name(project: @project, build_number: @build_number, target: target, environment: env, flavor: flavor)
            tarball_full_path = File.join(@output_dir, tarball)
            @shellrunner.check_call('tar', '-C', flavor_dir, '-czf', tarball_full_path, '.')
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
    # Render artifactory.json to output directory.
    artifactory_spec_path = File.join(@output_dir, 'artifactory.json')
    File.open(artifactory_spec_path, 'w') do |fh|
      fh.write(artifactory_spec)
    end
  end

  def artifactory_spec
    <<-EOF
{
  "files": [{
    "pattern": "#{@output_dir}/manifests:(*):(*):(*):(*):(*).tar.gz",
    "target": "kubernetes-snapshot-local/{1}/{2}/manifests_{3}_{4}_{5}.tar.gz",
    "props": "type=tgz;target={3};environment={4};flavor={5}",
    "recursive": false,
    "flat": true
  },
  {
    "pattern": "#{@output_dir}/images.yaml",
    "target": "kubernetes-snapshot-local/#{@project}/#{@build_number}/images.yaml",
    "flat": true
  }]
}
EOF
    end

    def render_erb_flags(flags)
      result = Hash.new

      flags.each do |key, template|
        renderer = ERB.new(template)
        result[key] = renderer.result
      end

      result
    end
  end
end
