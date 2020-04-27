require_relative 'driver_base'

require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/shellrunner'
require 'kube_deploy_tools/object'

require 'artifactory'
require 'fileutils'
require 'uri'


EXT_TAR_GZ = ".tar.gz"

module KubeDeployTools
  class ArtifactRegistry::Driver::Artifactory < ArtifactRegistry::Driver::Base
    # Artifactory configuration is configurable by environment variables
    # by default:
    # export ARTIFACTORY_ENDPOINT=http://my.storage.server/artifactory
    # export ARTIFACTORY_USERNAME=admin
    # export ARTIFACTORY_PASSWORD=password
    # See https://github.com/chef/artifactory-client#create-a-connection.

    def initialize(config:)
      @config = config

      Artifactory.endpoint = @config.fetch('endpoint', '')
      @repo = @config.fetch('repo', '')

      if Artifactory.endpoint.blank?
        Logger.warn("No Artifactory endpoint given")
      end
    end


    def get_local_artifact_path(name:, flavor:, local_dir:)
      artifact_name = get_artifact_name(name: name, flavor: flavor)

      local_artifact_path = File.join(local_dir, artifact_name)

      local_artifact_path
    end

    def get_registry_artifact_path(name:, flavor:, project:, build_number:)
      # NOTE(joshk): If the naming format changes, it represents a breaking
      # change where all past clients will not be able to download new builds and
      # new clients will not be able to download old builds. Change with caution.
      "#{project}/#{build_number}/#{get_artifact_name(name: name, flavor: flavor)}"
    end

    def publish(local_artifact_path:, registry_artifact_path:)
      if Artifactory.username.blank?
        Logger.warn("No Artifactory username given")
      end
      if Artifactory.password.blank?
        Logger.warn("No Artifactory password given")
      end

      artifactory_url = "#{Artifactory.endpoint}/#{@repo}/#{registry_artifact_path}"
      Logger.info("Uploading #{local_artifact_path} to #{artifactory_url}")
      artifact = Artifactory::Resource::Artifact.new(local_path: local_artifact_path)
      artifact.upload(@repo, registry_artifact_path)
    end

    def get_artifact_name(name:, flavor:)
      "manifests_#{name}_#{flavor}#{EXT_TAR_GZ}"
    end

    def generate(name:, flavor:, input_dir:, output_dir:)
      local_artifact_path = get_local_artifact_path(name: name, flavor: flavor, local_dir: output_dir)

      Shellrunner.check_call('tar', '-C', input_dir, '-czf', local_artifact_path, '.')

      local_artifact_path
    end

    def download(project:, build_number:, flavor:, name:, pre_apply_hook:, output_dir:)
      if build_number == 'latest'
        build_number = get_latest_build_number(project)
      end

      registry_artifact_path = get_registry_artifact_path(
        name: name, flavor: flavor, project: project, build_number: build_number)

      registry_artifact_full_path = [
        Artifactory.endpoint,
        @repo,
        registry_artifact_path,
      ].join('/')

      local_artifact_path = download_artifact(registry_artifact_full_path, output_dir)
      local_artifact_path = uncompress_artifact(local_artifact_path, output_dir)

      if pre_apply_hook
        out, err, status = Shellrunner.run_call(pre_apply_hook, local_artifact_path)
        if !status.success?
          raise "Failed to run post download hook #{pre_apply_hook}"
        end
      end

      local_artifact_path
    end

    def get_latest_build_number(project)
      project_url = [
        Artifactory.endpoint,
        @repo,
        "#{project}/"
      ].join('/')
      project_builds_html = Shellrunner.run_call('curl', project_url).first
      # store build entries string from html into an array
      build_links_pattern = /(?<=">).+(?=\s{4})/
      build_entries = project_builds_html.scan(build_links_pattern) # example of element: 10/</a>    13-Nov-2017 13:51
      build_number_pattern = /^\d+/
      build_number = build_entries.
        map { |x| x.match(build_number_pattern).to_s.to_i }.
        max.
        to_s
      if build_number.empty?
        raise "Failed to find a valid build number. Project URL: #{project_url}"
      end
      build_number
    end

    def download_artifact(input_path, output_dir_path)
      uri = URI.parse(input_path)
      filename = File.basename(uri.path)
      output_path = File.join(output_dir_path, filename)
      out, err, status = Shellrunner.run_call('curl', '-o', output_path, input_path, '--silent', '--fail')
      if !status.success?
        raise "Failed to download remote deploy artifact #{uri}"
      end

      output_path
    end

    def uncompress_artifact(input_path, output_dir_path)
      dirname = File.basename(input_path).chomp(EXT_TAR_GZ)
      output_path = File.join(output_dir_path, dirname)
      FileUtils.mkdir_p(output_path)
      out, err, status = Shellrunner.run_call('tar', '-xzf', input_path, '-C', output_path)
      if !status.success?
        raise "Failed to uncompress deploy artifact #{input_path}"
      end

      output_path
    end
  end
end
