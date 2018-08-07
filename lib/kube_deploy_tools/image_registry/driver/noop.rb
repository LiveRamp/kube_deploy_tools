require_relative 'base'

# Noop driver, does nothing!
module KubeDeployTools
  class ImageRegistry::Driver::Noop < ImageRegistry::Driver::Base
    def push_image(image)
    end

    def authorize
    end

    def unauthorize
    end
  end
end
