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
  def template_out(template, values)
    output = render_erb_with_hash template, values

    output
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

  def template(template, values, maybeOutputFilepath)
    raise 'Unexpected error: --template is neither a file nor directory' unless File.file?(template)

    if maybeOutputFilepath.present? && File.directory?(maybeOutputFilepath)
      maybeOutputFilepath = File.join(maybeOutputFilepath, File.basename(template, ".erb"))
    end

    output = template_out(template, values)

    if !maybeOutputFilepath
      $stdout.puts output
    elsif output.present?
      # Save file if output is not blank. This will suppress output file
      # generation when using ERB early returns at the top of an ERB template:
      # <% return if ... %>
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
end
