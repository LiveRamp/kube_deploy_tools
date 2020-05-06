require_relative 'driver_artifactory'
require_relative 'driver_gcs'

module KubeDeployTools
  class ArtifactRegistry
    module Driver
      MAPPINGS = {
        'artifactory' => Artifactory,
        'gcs' => GCS,
      }
    end
  end
end
