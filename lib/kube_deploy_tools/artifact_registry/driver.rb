require_relative 'driver_artifactory'

module KubeDeployTools
  class ArtifactRegistry
    module Driver
      MAPPINGS = {
        'artifactory' => Artifactory,
      }
    end
  end
end
