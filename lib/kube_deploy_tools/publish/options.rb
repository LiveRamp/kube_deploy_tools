require 'optparse'

require 'kube_deploy_tools/deploy_artifact'

module KubeDeployTools
  class Publish::Optparser
    class Options
      attr_accessor :extra_files, :manifest_file, :output_path

      def initialize
        Artifactory.endpoint = KubeDeployTools::ARTIFACTORY_ENDPOINT
        self.extra_files = []
        self.output_path = File.join('build', 'kubernetes')
      end

      # Artifactory configuration is configurable by environment variables
      # by default:
      # export ARTIFACTORY_ENDPOINT=http://my.storage.server/artifactory
      # export ARTIFACTORY_USERNAME=admin
      # export ARTIFACTORY_PASSWORD=password
      # See https://github.com/chef/artifactory-client#create-a-connection.
      def define_options(parser)
        parser.on('--url URL', 'Artifactory URL') do |p|
          Artifactory.endpoint = p
        end

        parser.on('--user USERNAME', 'Artifactory username') do |p|
          Artifactory.username = p
        end

        parser.on('--password PASSWORD', 'Artifactory password') do |p|
          Artifactory.password = p
        end

        parser.on('-iEXTRAFILE', '--include EXTRAFILE', 'Include extra files in the artifactory payload.') do |f|
          self.extra_files.push f
        end

        parser.on('-mMANIFEST', '--manifest MANIFEST', 'The configuration MANIFEST to render deploys with.') do |f|
          self.manifest_file = f
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
