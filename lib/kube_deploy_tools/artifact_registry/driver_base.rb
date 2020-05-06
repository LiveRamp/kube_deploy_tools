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

        # upload should publish the artifact identified by the given name and flavor
        # in the input directory to the corresponding location in the artifact
        # registry. The project and build number should be included in the
        # namespace of the artifact registry path for this artifact.
        def upload(local_dir:, name:, flavor:, project:, build_number:)
          raise "#{self.class}#publish not implemented"
        end

        # download should retrieve the artifact namespaced with the given
        # project and build number and identified by the name and flavor.
        # The artifact should be put into the output directory.
        # An optional pre-apply hook will process each artifact at the end.
        def download(project:, build_number:, flavor:, name:, pre_apply_hook:, output_dir:)
          raise "#{self.class}#download not implemented"
        end

        # get_latest_build_number should find the artifact from the most recent
        # build
        def get_latest_build_number(project)
          raise "#{self.class}#get_latest_build_number not implemented"
        end
      end
    end
  end
end
