require 'optparse'
require 'set'
require 'kube_deploy_tools/cluster_config.rb'

module KubeDeployTools
  class PublishContainer::Optparser

    class PublishContainerOptions
      attr_accessor :local_prefix, :registries, :images, :tag

      def initialize
        self.local_prefix = KubeDeployTools::CLUSTERS
          .fetch('local')
          .fetch('staging')
          .fetch('flags')
          .fetch('image_registry')
        self.registries = Set.new
        self.tag = KubeDeployTools::tag_from_local_env
      end

      def define_options(parser)
        parser.on('-lPREFIX', '--local-prefix PREFIX', 'The local Docker prefix to strip to get to the base image name') do |f|
          self.local_prefix = f
        end

        parser.on('-tTAG', '--tag TAG', 'Tag Docker images with TAG') do |t|
          self.tag = t
        end

        parser.on('-rPREFIX', '--registry REGISTRY', 'The remote Docker registry to push to (can specify multiple times)') do |r|
          self.registries.add r
        end
      end

    end

    def parse(args)
      @options = PublishContainerOptions.new
      OptionParser.new do |parser|
        @options.define_options(parser)
        parser.parse!(args)
      end
      @options
    end
  end
end
