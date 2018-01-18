require 'fileutils'
require 'uri'

require 'kube_deploy_tools/object'
require 'kube_deploy_tools/shellrunner'

EXT_TAR_GZ = ".tar.gz"
ARTIFACT_REPO="http://***REMOVED***/artifactory/kubernetes-snapshot-local/"

module KubeDeployTools
  def self.build_deploy_artifact_name(project:, build_number:, target:, environment:, flavor:)
    "manifests:#{project}:#{build_number}:#{target}:#{environment}:#{flavor}#{EXT_TAR_GZ}"
  end

  def self.get_remote_deploy_artifact_url(project:, build_number:, target:, environment:, flavor:)
    if build_number == 'latest'
      build_number = get_latest_build_number(project)
    end
    URI.join(
      ARTIFACT_REPO,
      "#{project}/#{build_number}/manifests_#{target}_#{environment}_#{flavor}#{EXT_TAR_GZ}",
    ).to_s
  end

  def self.get_latest_build_number(project)
    project_url = URI.join(ARTIFACT_REPO, "#{project}/").to_s
    html = Shellrunner.run_call('curl', project_url).first
    build_number_finder_pattern = /(?<=>)\w+(?=\/<\/a>)/
    html.scan(build_number_finder_pattern).last
  end

  class DeployArtifact
    def initialize(
      input_path:,
      output_dir_path: nil)

      @input_path = input_path
      @output_dir_path = output_dir_path
      raise ArgumentError, 'path is required' if input_path.blank?

      if !is_remote_deploy_artifact?(@input_path) &&
          !is_local_compressed_deploy_artifact?(@input_path) &&
          !File.directory?(@input_path)
        raise ArgumentError, "Expected path to a valid remote URL, local compressed archive, or local directory, received '#{@input_path}'"
      end
    end

    def path
      if is_remote_deploy_artifact?(@input_path)
        @input_path = download_remote_deploy_artifact(@input_path, @output_dir_path)
      end

      if is_local_compressed_deploy_artifact?(@input_path)
        @input_path = uncompress_local_deploy_artifact(@input_path, @output_dir_path)
      end

      @input_path
    end

    def is_remote_deploy_artifact?(input_path)
      uri = URI.parse(input_path)
      %w( http https ).include?(uri.scheme)
    rescue URI::BadURIError
      false
    rescue URI::InvalidURIError
      false
    end

    def download_remote_deploy_artifact(input_path, output_dir_path)
      uri = URI.parse(input_path)
      filename = File.basename(uri.path)
      output_path = File.join(output_dir_path, filename)
      out, err, status = Shellrunner.run_call('curl', '-o', output_path, input_path, '--silent', '--fail')
      if !status.success?
        raise "Failed to download remote deploy artifact #{uri}"
      end

      output_path
    end

    def is_local_compressed_deploy_artifact?(input_path)
      File.file?(input_path) && input_path.end_with?(EXT_TAR_GZ)
    end

    def uncompress_local_deploy_artifact(input_path, output_dir_path)
      dirname = File.basename(input_path).chomp(EXT_TAR_GZ)
      output_path = File.join(output_dir_path, dirname)
      FileUtils.mkdir_p(output_path)
      out, err, status = Shellrunner.run_call('tar', '-xzf', input_path, '-C', output_path)
      if !status.success?
        raise "Failed to uncompress deploy artifact #{input_path}"
      end

      output_path
    end

    def is_local_deploy_artifact?(input_path)
      File.directory?(input_path)
    end

  end

end

