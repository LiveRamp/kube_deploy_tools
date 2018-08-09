#!/usr/bin/env ruby
# Default rendering hook. Uses built in `templater` to render out all files
# underneath kubernetes/ directory, recursively.

require 'fileutils'
require 'json'
require 'yaml'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/templater'

module KubeDeployTools
  module RenderDeploysHook
    TEMPLATING_SUFFIX = '.erb'

    def self.render_deploys(config_file, input_dir, output_root)
      # Parse config into a struct.
      config = YAML.load_file(config_file)
      t = KubeDeployTools::Templater.new

      Dir[File.join(input_dir, "**", "*.y*ml*")].each do |yml|
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

        puts output_file

        # Bonus: YAML validate the output.
        begin
          if File.file?(output_file)
            YAML.load_file(output_file)
          end
        rescue => e
          raise "Failed to YAML validate #{output_file} (generated from #{yml}): #{e}"
        end
      end
    end
  end
end
