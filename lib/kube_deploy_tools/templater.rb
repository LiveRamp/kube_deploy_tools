# Heart of the templating engine used by render_deploys.
require 'erb'
require 'fileutils'

require 'kube_deploy_tools/object'

module KubeDeployTools

  class Templater
    def template(template, values)
      output = render_erb_with_hash template, values

      output
    end

    def render_erb_with_hash(template, values)
      begin
        renderer = ERB.new(File.read(template), nil, '-')
        config = StrictHash.new(values)
        renderer.result(binding)
      rescue Exception => e
        raise "Error rendering template #{template} with #{config}: #{e}"
      end
    end

    def template_to_file(template, values, maybeOutputFilepath = nil)
      raise "Expected template to be an existing file, received '#{template}''" unless File.file?(template)
      raise "Expected output filepath to be a new filepath, received '#{maybeOutputFilepath}'" if maybeOutputFilepath.present? && (File.file?(maybeOutputFilepath) || File.directory?(maybeOutputFilepath))

      output = template(template, values)

      # If an output filepath is not given, print to stdout
      if !maybeOutputFilepath
        $stdout.puts output
      elsif output.present?
        # Save file if output is not blank. This will suppress output file
        # generation when using ERB early returns at the top of an ERB template:
        # <% return if ... %>
        FileUtils.mkdir_p(File.dirname(maybeOutputFilepath))
        File.open(maybeOutputFilepath, "w") { |f| f << output }
      end
    end
  end

  class StrictHash
    def initialize(h)
      @h = h
    end

    def [](k)
      @h.fetch(k)
    end

    def fetch(*args)
      @h.fetch(*args)
    end

    def get_or_nil(k)
      @h[k]
    end
  end
end

