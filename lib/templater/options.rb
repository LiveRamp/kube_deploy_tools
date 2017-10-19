require 'optparse'
require 'yaml'

class Optparser

  class TemplaterOptions
    attr_accessor :output,
                  :template,
                  :values,
                  :values_from_flags,
                  :values_from_yaml

    def initialize
      # Values available in the ERB template to be merged.
      # Avoid errors by forcing explicit checks for keys. With this, config[]
      # indirection requires the key to exist.
      self.values = {}
      self.values_from_yaml = {}
      self.values_from_flags = {}
    end

    def define_options(parser)
      parser.on('-tFILEPATH', '--template FILEPATH', 'The template file FILEPATH') do |f|
        self.template = f
      end

      parser.on('-vFILENAME', '--values FILENAME', 'Set template variables from the values in a YAML file, FILENAME') do |f|
        raise "Cannot find --values FILENAME '#{f}'" unless File.file?(f)
        self.values_from_yaml = YAML::load(File.read(f))
      end

      parser.on('-sKEY=VALUE', '--set KEY=VALUE', 'Set a template variable with KEY=VALUE') do |kv|
        raise "Cannot parse --set KEY=VALUE '#{kv}'" unless kv.include? '='
        k, v = *kv.split("=")
        self.values_from_flags[k] = v
      end

      parser.on('-oFILEPATH', '--output FILEPATH', 'Set the output file FILEPATH. Default output is to stdout.') do |f|
        self.output = f
      end
    end

    def require_options
      raise 'Must provide --template' unless template.present?
      raise "Cannot find --template FILEPATH '#{template}'" unless File.file?(template)
      raise "Expected --template FILEPATH '#{template}' to end with .yaml.erb" unless template.end_with?(".yaml.erb")
      raise "Expected --output FILEPATH to be a new file location" unless output.blank? || !File.file?(output) || File.directory?(output)
    end

    def merge_values
      # merge values from yaml
      self.values = self.values.merge(self.values_from_yaml)

      # merge values from flags
      self.values = self.values.merge(self.values_from_flags)

      warn 'Warning: No values provided from --values, --set' unless ! self.values.empty?
    end

  end

  def parse(args)
    @options = TemplaterOptions.new
    OptionParser.new do |parser|
      @options.define_options(parser)
      parser.parse!(args)
      @options.require_options
    end
    @options
  end
end
