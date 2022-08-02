require 'optparse'

module KubeDeployTools
  class Publish::Optparser
    class Options
      attr_accessor :manifest_file, :input_path, :output_path

      def initialize
        self.input_path = File.join('build', 'kubernetes')
        self.output_path = File.join('build', 'kubernetes')
      end

      def define_options(parser)
        parser.on('-mMANIFEST', '--manifest MANIFEST', 'The configuration MANIFEST to render deploys with.') do |f|
          self.manifest_file = f
        end

        parser.on('-iPATH', '--input-path PATH', 'Path where local artifact to be deployed is located.') do |p|
          self.input_path = p
        end

        parser.on('-oPATH', '--output-path PATH', 'Path where rendered manifests are written.') do |p|
          self.output_path = p
        end

        parser.on('-')
      end
    end

    def parse(args)
      @options = Options.new
      OptionParser.new do |parser|
        @options.define_options(parser)
        parser.parse(args)
      end
      @options
    end
  end
end
