#!/usr/bin/env ruby
# Default rendering hook. Uses built in `templater` to render out all files
# underneath kubernetes/ directory, recursively.

require 'fileutils'
require 'json'
require 'yaml'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/templater'
require 'kube_deploy_tools/file_filter'

module KubeDeployTools
  module RenderDeploysHook
    TEMPLATING_SUFFIX = '.erb'

    def self.render_deploys(config_file, input_dir, output_root, file_filters)
      # Parse config into a struct.
      config = YAML.load_file(config_file)
      t = KubeDeployTools::Templater.new

      get_valid_files(file_filters, input_dir).each do |yml|
        # PREFIX/b/c/foo.yml.in -> foo.yml
        output_base = File.basename(yml, TEMPLATING_SUFFIX)

        # PREFIX/b/c/foo.yml.in -> b/c
        subdir = File.dirname(yml[input_dir.size..-1])

        # PREFIX/b/c/foo.yml.in -> output/b/c/foo.yml
        if subdir == '.'
          # If |subdir| is '.', joining it with output_root results in
          # output_root/. , which is not concise for human readability.
          # Handle this case explicitly.
          output_dir = output_root
        else
          output_dir = File.join(output_root, subdir)
        end
        output_file = File.join(output_dir, output_base)

        if yml.end_with? TEMPLATING_SUFFIX
          # File needs to be templated with templater.
          Logger.info("Generating #{output_file} from #{yml}")
          t.template_to_file(yml, config, output_file)
        else
          # File is not templatable, and is copied verbatim.
          Logger.info("Copying #{output_file} from #{yml}")
          FileUtils.mkdir_p output_dir
          FileUtils.copy(yml, output_file)
        end

        # Bonus: YAML validate the output.
        # * Must be valid YAML
        # * If .kind is a type that takes .metadata.namespace, then require
        #   that .metadata.namespace is present.
        begin
          if File.file?(output_file)
            yaml = []
            YAML.load_stream(File.read(output_file)) { |doc| yaml << doc }
            yaml.each do |data|
              # XXX(joshk): Non-exhaustive list.
              must_have_ns = [
                'ConfigMap', 'CronJob', 'DaemonSet', 'Deployment', 'Endpoints', 'HorizontalPodAutoscaler',
                'Ingress', 'PersistentVolumeClaim', 'PodDisruptionBudget', 'ServiceAccount', 'Secret', 'Service'
              ]
              if must_have_ns.member?(data.fetch('kind'))
                raise "Rendered Kubernetes template missing a .metadata.namespace: #{yml}" if data.fetch('metadata', {}).fetch('namespace', '').empty?
              end
              # annotation added to each manifest
              if config['git_commit']
                if data['metadata'].key?('annotations')
                  data['metadata']['annotations']['git_commit'] = config['git_commit']
                else
                  data['metadata']['annotations'] = { 'git_commit' => config['git_commit'] }
                end
              end

              if config['git_project']
                data['metadata']['annotations']['git_project'] = config['git_project']
              end
            end
            File.open(output_file, 'w') { |f| f << YAML.dump_stream(*yaml) }
          end
        rescue => e
          raise "Failed to YAML validate #{output_file} (generated from #{yml}): #{e}"
        end
      end
    end

    def self.get_valid_files(file_filters, input_dir)
      filtered_files = FileFilter.filter_files(filters: file_filters, files_path: input_dir)
      filtered_files.select { |f| f =~ /\.y.?ml[^\/]*$/ }
    end
  end
end
