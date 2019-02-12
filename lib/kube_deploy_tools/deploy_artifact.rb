require 'artifactory'
require 'fileutils'
require 'uri'

require 'kube_deploy_tools/object'
require 'kube_deploy_tools/shellrunner'

EXT_TAR_GZ = ".tar.gz"

module KubeDeployTools
  PROJECT = ENV['JOB_NAME'] || File.basename(`git config remote.origin.url`.chomp, '.git')
  BUILD_NUMBER = ENV.fetch('BUILD_ID', 'dev')

  ARTIFACTORY_ENDPOINT = "https://***REMOVED***/artifactory"
  ARTIFACTORY_REPO = "kubernetes-snapshot-local"

  def self.build_deploy_artifact_name(name:, flavor:)
    "manifests_#{name}_#{flavor}#{EXT_TAR_GZ}"
  end

  def self.get_remote_deploy_artifact_key(project:, build_number:, name:, flavor:)
    # NOTE(joshk): If the naming format changes, it represents a breaking
    # change where all past clients will not be able to download new builds and
    # new clients will not be able to download old builds. Change with caution.
    "#{project}/#{build_number}/#{build_deploy_artifact_name(name: name, flavor: flavor)}"
  end

  def self.get_remote_deploy_artifact_url(project:, build_number:, name:, flavor:)
    if build_number == 'latest'
      build_number = get_latest_build_number(project)
    end
    [
      Artifactory.endpoint,
      ARTIFACTORY_REPO,
      get_remote_deploy_artifact_key(project: project, build_number: build_number, flavor: flavor, name: name),
    ].join('/')
  end

  def self.get_latest_build_number(project)
    project_url = [
      Artifactory.endpoint,
      ARTIFACTORY_REPO,
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

  class DeployArtifact
    def initialize(
      input_path:,
      output_dir_path: nil,
      pre_apply_hook: nil)

      @input_path = input_path
      @output_dir_path = output_dir_path
      @pre_apply_hook = pre_apply_hook
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

      if @pre_apply_hook
        out, err, status = Shellrunner.run_call(@pre_apply_hook, @input_path)
        if !status.success?
          raise "Failed to run post download hook #{@pre_apply_hook}"
        end
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
