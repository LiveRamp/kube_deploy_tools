require 'optparse'

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
        :pre_apply_hook,
        :max_retries,
        :retry_delay

      def initialize
        self.project = File.basename(`git config remote.origin.url`.chomp, '.git')
        self.flavor = 'default'
        self.dry_run = true
        self.glob_files = []
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

        parser.on('--dry-run DRY_RUN', TrueClass, "If true, will only dry-run apply Kubernetes manifests without sending them to the apiserver. Default is dry-run mode: #{dry_run}.") do |p|
          self.dry_run = p
        end

        parser.on('--include INCLUDE', "Include glob pattern. Example: --include=**/* will include every file. Default is ''.") do |p|
          self.glob_files.push(["include_files", p])
        end

        parser.on('--exclude EXCLUDE', "Exclude glob pattern. Example: --exclude=**/gazette/* will exclude every file in gazette folder. Default is ''.") do |p|
          self.glob_files.push(["exclude_files", p])
        end

        parser.on('--include-dir INCLUDE', "Recursively include all files in a directory and its subdirectories. Example: --include-dir=gazette/ (equivalent of --include=**/gazette/**/*)") do |p|
          self.glob_files.push(["include_dir", p])
        end

        parser.on('--exclude-dir EXCLUDE', "Recursively exclude all files in a directory and its subdirectories. Example: --exclude-dir=gazette/ (equivalent of --exclude=**/gazette/**/*)") do |p|
          self.glob_files.push(["exclude_dir", p])
        end

        parser.on("--pre-apply-hook CMD", "Shell command to run with the output directory before applying files") do |p|
          self.pre_apply_hook = p
        end

        parser.on('--retry NUM', 'Maximum number of times to retry') do |p|
          self.max_retries = p
        end

        parser.on('--retry-delay NUM', 'Delay in seconds between retries') do |p|
          self.retry_delay = p
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
