require 'artifactory'
require 'optparse'

require 'kube_deploy_tools/deploy_artifact'
require 'kube_deploy_tools/object'

module KubeDeployTools
  class Deploy::Optparser
    class Options
      attr_accessor :kubeconfig,
        :context,
        :from_files,
        :project,
        :flavor,
        :artifact,
        :build_number,
        :dry_run,
        :glob_files,
        :pre_apply_hook

      def initialize
        self.project = File.basename(`git config remote.origin.url`.chomp, '.git')
        self.flavor = 'default'
        self.dry_run = true
        self.glob_files = []

        Artifactory.endpoint = KubeDeployTools::ARTIFACTORY_ENDPOINT
      end

      def define_options(parser)
        parser.on('-fPATH', '--from-files FILEPATH', 'Filename, directory, or artifact URL that contains the Kubernetes manifests to apply') do |p|
          self.from_files = p
        end

        parser.on('--kubeconfig FILEPATH', 'Path to the kubconfig file to use for kubectl requests') do |p|
          self.kubeconfig = p
        end

        parser.on('--context CONTEXT', 'The kubeconfig context to use') do |p|
          self.context = p
        end

        parser.on('--project PROJECT', "The project to deploy. Default is '#{project}'.") do |p|
          self.project = p
        end

        parser.on('--flavor FLAVOR', "The flavor to deploy. Default is '#{flavor}'") do |p|
          self.flavor = p
        end

        parser.on('--artifact ARTIFACT', 'The artifact name to deploy') do |p|
          self.artifact = p
        end

        parser.on('--build BUILD', 'The Jenkins build number to deploy') do |p|
          self.build_number = p
        end

        parser.on('--dry-run DRY_RUN', "If true, will only dry-run apply Kubernetes manifests without sending them to the apiserver. Default is dry-run mode: #{dry_run}.") do |p|
          self.dry_run = p
        end

        parser.on('--include INCLUDE', "Include glob pattern. Example: --inlude=**/* will include every file. Default is ''.") do |p|
          self.glob_files.push(Hash["include_files" => p])
        end

        parser.on('--exclude EXCLUDE', "Exclude glob pattern. Example: --exclude=**/gazette/* will exclude every file in gazette folder. Default is ''.") do |p|
          self.glob_files.push(Hash["exclude_files" => p])
        end

        parser.on("--pre-apply-hook CMD", "Shell command to run with the output directory before applying files") do |p|
          self.pre_apply_hook = p
        end

        # Artifactory configuration is configurable by environment variables
        # by default:
        # export ARTIFACTORY_ENDPOINT=http://my.storage.server/artifactory
        # See https://github.com/chef/artifactory-client#create-a-connection.
        parser.on('--url URL', 'Artifactory URL') do |p|
          Artifactory.endpoint = p
        end

        parser.on('-')
      end

      def require_options
        raise ArgumentError, 'Expect --context to be provided' if context.blank?

        files_mode = from_files.present? && (artifact.blank? && build_number.blank?)
        deploy_artifact_mode = from_files.blank? && (artifact.present? && flavor.present? && build_number.present?)

        if !files_mode && !deploy_artifact_mode
          raise ArgumentError, 'Expect either --from-files or all of [--artifact, --flavor, --build] to be provided'
        end
      end
    end

    def parse(args)
      @options = Options.new
      OptionParser.new do |parser|
        @options.define_options(parser)
        parser.parse(args)
        @options.require_options
      end
      @options
    end
  end
end
