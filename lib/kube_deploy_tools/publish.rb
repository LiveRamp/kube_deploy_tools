require 'artifactory'
require 'uri'
require 'yaml'

require 'kube_deploy_tools/built_artifacts_file'
require 'kube_deploy_tools/deploy_config_file'
require 'kube_deploy_tools/deploy_artifact'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/object'

module KubeDeployTools
  class Publish
    def initialize(manifest:, output_dir:)
      @config = DeployConfigFile.new(manifest)
      @output_dir = output_dir

      @project = KubeDeployTools::PROJECT
      @build_number = KubeDeployTools::BUILD_NUMBER

      if Artifactory.endpoint.blank?
        Logger.warn("No Artifactory endpoint given")
      end
      if Artifactory.username.blank?
        Logger.warn("No Artifactory username given")
      end
      if Artifactory.password.blank?
        Logger.warn("No Artifactory password given")
      end
    end

    def publish()
      @config.artifacts.each do |c|
        name = c.fetch('name')
        # Allow deploy.yaml to gate certain flavors to certain targets.
        cluster_flavors = @config.flavors.select { |key, value| c['flavors'].nil? || c['flavors'].include?(key) }
        cluster_flavors.each do |flavor, _|
          tarball = KubeDeployTools.build_deploy_artifact_name(
            name: name,
            flavor: flavor
          )
          tarball_full_path = File.join(@output_dir, tarball)
          artifactory_repo_key = KubeDeployTools.get_remote_deploy_artifact_key(
            project: @project,
            build_number: @build_number,
            name: name,
            flavor: flavor
          )

          if File.exist?(tarball_full_path)
            upload_artifact(
              file_path: tarball_full_path,
              artifactory_repo_key: artifactory_repo_key,
            )
          else
            Logger.warn("Expected artifact to exist, but #{tarball_full_path} does not exist")
          end
        end
      end
    end

    def upload_artifact(file_path:, artifactory_repo_key:)
      artifactory_url = "#{Artifactory.endpoint}/#{KubeDeployTools::ARTIFACTORY_REPO}/#{artifactory_repo_key}"
      Logger.info("Uploading #{file_path} to #{artifactory_url}")
      artifact = Artifactory::Resource::Artifact.new(local_path: file_path)
      artifact.upload(KubeDeployTools::ARTIFACTORY_REPO, artifactory_repo_key)
    end
  end
end
