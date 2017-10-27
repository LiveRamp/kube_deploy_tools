class Optparser

  class PushContainerOptions
    attr_accessor :local_prefix, :registry, :images, :tag

    def initialize
      self.local_prefix = 'local-registry/'
      self.registry = 'aws'
      self.tag = tag_from_local_env
    end

    def define_options(parser)
      parser.on('-lPREFIX', '--local-prefix PREFIX', 'The local Docker prefix to strip to get to the base image name') do |f|
        self.template = f
      end

      parser.on('-tTAG', '--tag TAG', 'Tag Docker images with TAG') do |t|
        self.tag = t
      end

      parser.on('-rPREFIX', '--registry REGISTRY', 'The remote Docker registry to push to') do |r|
        self.registry = r
      end
    end

  end

  def parse(args)
    @options = PushContainerOptions.new
    OptionParser.new do |parser|
      @options.define_options(parser)
      parser.parse!(args)
    end
    @options
  end
end
