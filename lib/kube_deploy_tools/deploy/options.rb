require 'optparse'
require 'kube_deploy_tools/object'

module KubeDeployTools
  class Deploy::Optparser
    class Options
      attr_accessor :kubeconfig,
        :context,

        :from_files,

        :project,
        :target,
        :environment,
        :flavor,
        :build_number,
        :dry_run

      def initialize
        self.project = File.basename(`git config remote.origin.url`.chomp, '.git')
        self.flavor = 'default'
        self.dry_run = true
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

        parser.on('--target TARGET', 'The target to deploy') do |p|
          self.target = p
        end

        parser.on('--environment ENVIRONMENT', 'The environment to deploy') do |p|
          self.environment = p
        end

        parser.on('--flavor FLAVOR', "The flavor to deploy. Default is '#{flavor}'") do |p|
          self.flavor = p
        end

        parser.on('--build BUILD', 'The Jenkins build number to deploy') do |p|
          self.build_number = p
        end

        parser.on('--dry-run DRY_RUN', "If true, will only dry-run apply Kubernetes manifests without sending them to the apiserver. Default is dry-run mode: #{dry_run}.") do |p|
          self.dry_run = p
        end

        parser.on('-')
      end

      def require_options
        raise ArgumentError, 'Expect --target and --environment, or --context, to be provided' if (target.blank? || environment.blank?) && context.blank?

        files_mode = from_files.present? && (target.blank? && environment.blank? && build_number.blank?)
        deploy_artifact_mode = from_files.blank? && (target.present? && environment.present? && build_number.present?)

        if !files_mode && !deploy_artifact_mode
          raise ArgumentError, 'Expect either --from-files or all of [--target, --environment, --flavor, --build] to be provided'
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
