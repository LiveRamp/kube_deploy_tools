require_relative 'driver/base'
require_relative 'driver/aws'
require_relative 'driver/gcp'
require_relative 'driver/login'
require_relative 'driver/noop'

module KubeDeployTools
  class ImageRegistry
    module Driver
      MAPPINGS = {
        'aws' => Aws,
        'gcp' => Gcp,
        'login' => Login,
        'noop' => Noop
      }
    end
  end
end
