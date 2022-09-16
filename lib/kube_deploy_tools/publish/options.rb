require 'optparse'

module KubeDeployTools
  class Publish::Optparser
    class Options
      attr_accessor :manifest_file, :output_path, :env, :app

      def env
          @env || nil
        end

      def app
          @app || nil
        end

      def initialize
        self.output_path = File.join('build', 'kubernetes')
      end

      def define_options(parser)
        parser.on('-mMANIFEST', '--manifest MANIFEST', 'The configuration MANIFEST to render deploys with.') do |f|
          self.manifest_file = f
        end

        parser.on('-oPATH', '--output-path PATH', 'Path where rendered manifests are written.') do |p|
          self.output_path = p
        end

        parser.on('-e', '--env-name NAME', 'Env name') do |p|
          self.env = p
        end

        parser.on('-a', '--app-name NAME', 'App name') do |p|
          self.app = p
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
