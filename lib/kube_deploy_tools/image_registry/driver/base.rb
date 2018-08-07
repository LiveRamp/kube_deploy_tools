require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/shellrunner'

require 'kube_deploy_tools/image_registry/image'

# Abstract Driver class that specific implementations inherit
module KubeDeployTools
  class ImageRegistry
    module Driver
      class Base
        def initialize(registry:)
          @registry = registry
        end

        def push_image(image)
          Shellrunner.check_call('docker', 'push', image.full_tag)
        end

        def authorize
          Logger.info "performing registry login for #{@registry.prefix}"
          Shellrunner.check_call(*authorize_command, print_cmd: false)
        end

        def authorize_command
          raise "#{self.class}#authorize_command needs explicit implementation"
        end

        def unauthorize
          Logger.info "Performing registry unauthorization for #{@registry.prefix}"
          Shellrunner.check_call(*unauthorize_command, print_cmd: false)
        end

        def unauthorize_command
          raise "#{self.class}#unauthorize_command needs explicit implementation"
        end
      end
    end
  end
end
