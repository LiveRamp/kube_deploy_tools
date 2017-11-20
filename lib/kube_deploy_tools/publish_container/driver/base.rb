require_relative '../image'

# Abstract Driver class that specific implementations inherit
module KubeDeployTools
  class PublishContainer
    module Driver
      class Base
        def initialize(registry:, shellrunner:)
          @registry = registry
          @shellrunner = shellrunner
        end

        def push_image(image)
          @shellrunner.check_call('docker', 'push', image.full_tag)
        end

        def authorize
          @shellrunner.check_call(*authorize_command)
        end

        def authorize_command
          raise "#{self.class}#authorize_command needs explicit implementation"
        end
      end
    end
  end
end
