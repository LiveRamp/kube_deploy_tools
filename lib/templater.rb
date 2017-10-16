# Heart of the templating engine used by render_deploys.
require 'erb'

class Object
  def present?
    self && to_s.strip != ''
  end

  def blank?
    !present?
  end
end

class Templater
  def template_out(template, values, outputFile = nil)
    output = render_erb_with_hash template, values
    if !outputFile
      $stdout.puts output
    else
      File.open(outputFile, "w") { |f| f << output }
    end
  end

  def render_erb_with_hash(template, values)
    begin
      renderer = ERB.new(File.read(template))
      config = StrictHash.new(values)
      renderer.result(binding)
    rescue Exception => e
      raise "Error rendering template #{template} with #{config}: #{e}"
    end
  end

  def template(template, values, maybeOutput)
    raise 'Unexpected error: --template is neither a file nor directory' unless File.file?(template)

    if maybeOutput.present? && File.directory?(maybeOutput)
      output = File.join(maybeOutput, File.basename(template, ".erb"))
    end
    template_out(template, values, output)
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
end
