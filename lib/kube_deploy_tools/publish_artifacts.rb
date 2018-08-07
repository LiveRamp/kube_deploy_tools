require 'artifactory'
require 'uri'
require 'yaml'

require 'kube_deploy_tools/built_artifacts_file'
require 'kube_deploy_tools/deploy_artifact'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/object'

module KubeDeployTools
  class PublishArtifacts
    def initialize(
      manifest:,
      output_dir:,
      extra_files:)
      unless File.file?(manifest)
        raise "Can't read deploy manifest: #{manifest}"
      end
      @manifest = YAML.load(File.read(manifest)).fetch('deploy')
      @output_dir = output_dir
      @extra_files = extra_files

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
      clusters = @manifest.fetch('clusters')
      flavors = @manifest.fetch('flavors')
      clusters.each do |c|
        target = c.fetch('target')
        env = c.fetch('environment')
        # Allow deploy.yml to gate certain flavors to certain targets.
        cluster_flavors = flavors.reject { |key, value| !(c['flavors'].nil? or c['flavors'].include? key) }
        cluster_flavors.each do |flavor, _|
          tarball = KubeDeployTools.build_deploy_artifact_name(
            project: @project,
            build_number: @build_number,
            target: target,
            environment: env,
            flavor: flavor
          )
          tarball_full_path = File.join(@output_dir, tarball)
          artifactory_repo_key = KubeDeployTools.get_remote_deploy_artifact_key(
            project: @project,
            build_number: @build_number,
            target: target,
            environment: env,
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

      images_yaml = File.join(@output_dir, 'images.yaml')

      @extra_files.each do |f|
        base = File.basename(f)
        upload_artifact(
          file_path: f,
          artifactory_repo_key:
          "#{@project}/#{@build_number}/#{base}",
        )

        manifest = KubeDeployTools::BuiltArtifactsFile.new(images_yaml)
        manifest.extra_files.add base

        Logger.info("Registered #{f} as extra artifact of the build")
      end

      if File.exist?(images_yaml)
        upload_artifact(
          file_path: images_yaml,
          artifactory_repo_key: "#{@project}/#{@build_number}/images.yaml",
        )
      else
        Logger.warn("Expected artifact to exist, but #{images_yaml} does not exist")
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
