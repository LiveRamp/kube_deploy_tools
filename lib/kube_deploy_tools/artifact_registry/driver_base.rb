require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/shellrunner'

# Abstract Driver class that specific implementations inherit
module KubeDeployTools
  class ArtifactRegistry
    module Driver
      class Base
        def initialize(config:)
          @config = config
        end

        def get_local_artifact_path(name:, flavor:, local_dir:)
          raise "#{self.class}#get_local_artifact_path not implemented"
        end

        def get_registry_artifact_path(name:, flavor:, project:, build_number:)
          raise "#{self.class}#get_registry_artifact_path not implemented"
        end

        def publish(local_artifact_path:, registry_artifact_path:)
          raise "#{self.class}#publish not implemented"
        end

        def generate(name:, flavor:, input_dir:, output_dir:)
          raise "#{self.class}#prepare_artifact not implemented"
        end

        def download(project:, build_number:, flavor:, name:, pre_apply_hook:, output_dir:)
          raise "#{self.class}#prepare_artifact not implemented"
        end
      end
    end
  end
end
