# frozen_string_literal: true

require 'json'
require 'set'
require 'yaml'
require 'date'
require 'kube_deploy_tools/errors'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/kubernetes_resource'
require 'kube_deploy_tools/kubernetes_resource/deployment'
require 'kube_deploy_tools/concurrency'
require 'kube_deploy_tools/file_filter'

# NOTE(jmodes): the order matters, and predeploy resources will be deployed
# in order.
# e.g. Namespaces will be deployed before Services and ConfigMaps, which
# are namespaced resources that may depend on deploying Namespaces first.
PREDEPLOY_RESOURCES = %w[
  Namespace
  StorageClass
  ServiceAccount
  ClusterRole
  Role
  ClusterRoleBinding
  RoleBinding
  CustomResourceDefinition
  ThirdPartyResource
  ConfigMap
  Service
].freeze

# TODO: (aaron): make these configurable
DEPLOY_LOG = 'projects/***REMOVED***/logs/deploys'
DEPLOY_PROJECT = '***REMOVED***'

module KubeDeployTools
  class Deploy
    def initialize(
      kubectl:,
      namespace: nil,
      input_path:,
      glob_files: [],
      max_retries: 3,
      retry_delay: 1
    )
      @kubectl = kubectl
      @namespace = namespace
      @input_path = input_path

      if !File.exists?(@input_path)
        Logger.error("Path doesn't exist: #{@input_path}")
        raise ArgumentError, "Path doesn't exist #{@input_path}"
      elsif File.directory?(@input_path)
        @glob_files = glob_files
        @filtered_files = FileFilter
                          .filter_files(filters: @glob_files, files_path: @input_path)
                          .select { |f| f.end_with?('.yml', '.yaml') }
      elsif File.file?(@input_path)
        @filtered_files = [@input_path]
        if !@glob_files.nil? && @glob_files.length > 0
          Logger.error("Single-file artifacts do not support glob exclusions: #{@input_path}")
          raise ArgumentError
        end
      end

      @max_retries = max_retries.nil? ? 3 : max_retries.to_i
      @retry_delay = retry_delay.to_i
    end

    def do_deploy(dry_run)
      success = false
      Logger.reset
      Logger.phase_heading('Initializing deploy')
      Logger.warn('Running in dry-run mode') if dry_run

      if !@namespace.nil? && @namespace != 'default'
        Logger.warn("Deploying to non-default Namespace: #{@namespace}")
      end

      resources = read_resources(@filtered_files)

      Logger.phase_heading('Checking initial resource statuses')
      KubernetesDeploy::Concurrency.split_across_threads(resources, &:sync)

      Logger.phase_heading('Checking deployment replicas match')
      deployments = resources
                    .select { |resource| resource.definition['kind'] == 'Deployment' }
      KubernetesDeploy::Concurrency.split_across_threads(deployments, &:warn_replicas_mismatch)

      Logger.phase_heading('Deploying all resources')
      # Deploy predeploy resources first, in order.
      # Then deploy the remaining resources in any order.
      deploy_resources = resources.sort_by do |r|
        PREDEPLOY_RESOURCES.index(r.definition['kind']) || PREDEPLOY_RESOURCES.length
      end

      kubectl_apply(deploy_resources, dry_run: dry_run)

      success = true
    ensure
      Logger.print_summary(success)
      success
    end

    def run(dry_run: true, send_report: true)
      notify(project_info.merge({'type':'deploy'}).to_json) if !dry_run && send_report
      do_deploy(dry_run)
    end

    def project_info
      git_commit, git_project = git_annotations
      # send a notification about the deployed code
      {
        'git_commit': git_commit,
        'git_project': git_project,
        'kubernetes-cluster': kubectl_cluster_server,
        'kubernetes-cluster-name': kubectl_cluster_name,
        'time': DateTime.now,
        'user': current_user
      }
    end

    def read_resources(filtered_files = Dir[File.join(@input_path, '**', '*')])
      resources = []
      filtered_files.each do |filepath|
        resource_definition(filepath) do |resource|
          resources << resource
        end
      end
      resources
    end

    def resource_definition(filepath)
      read_resource_definition(filepath) do |resource_definition|
        yield KubeDeployTools::KubernetesResource.build(
          definition: resource_definition,
          kubectl: @kubectl
        )
      end
    end

    def git_annotations
      resource_definition(@filtered_files.first) do |resource|
        if resource.annotations
          git_commit  = resource.annotations['git_commit']
          git_project = resource.annotations['git_project']
          return [git_commit, git_project]
        end
      end
      [nil, nil]
    end

    def read_resource_definition(filepath)
      file_content = File.read(filepath)
      YAML.load_stream(file_content) do |doc|
        yield doc if !doc.nil? && !doc.empty?
      end
    rescue Psych::SyntaxError => e
      debug_msg = <<~INFO
        Error message: #{e}
        Template content:
        ---
      INFO
      debug_msg += file_content
      Logger.debug(debug_msg)
      raise FatalDeploymentError, "Template '#{filepath}' cannot be parsed"
    end

    def kubectl_apply(resources, dry_run: true)
      resources.each do |resource|
        @max_retries.times do |try|
          args = ['apply', '-f', resource.filepath, "--dry-run=#{dry_run}"]
          out, _, status = @kubectl.run(*args)
          if status.success?
            Logger.info(out)
            break
          elsif try < @max_retries - 1
            sleep(@retry_delay)
            next
          end
          raise FatalDeploymentError, "Failed to apply resource '#{resource.filepath}'"
        end
      end
    end

    def kubectl_cluster_name
      args = ['config', 'view', '--minify', '--output=jsonpath={..clusters[0].name}']
      name, _, status = @kubectl.run(*args)
      unless status.success?
        raise FatalDeploymentError, 'Failed to determine cluster name'
      end
      name
    end

    def kubectl_cluster_server
      args = ['config', 'view', '--minify', '--output=jsonpath={..cluster.server}']
      server, _, status = @kubectl.run(*args)
      unless status.success?
        raise FatalDeploymentError, 'Failed to determine cluster server'
      end
      server
    end

    def self.kube_namespace(context:, kubeconfig: nil)
      args = [
        'kubectl', 'config', 'view', '--minify', '--output=jsonpath={..namespace}',
        "--context=#{context}"
      ]
      args.push("--kubeconfig=#{kubeconfig}") if kubeconfig.present?
      namespace, = Shellrunner.check_call(*args)
      namespace = 'default' if namespace.to_s.empty?

      namespace
    end

    def current_user
      Shellrunner.run_call('gcloud', 'config', 'list', 'account', '--format', 'value(core.account)')[0]
    end

    def notify(message)
      args = [
        'gcloud', 'logging', 'write', "--project=#{DEPLOY_PROJECT}",
        '--payload-type=json', DEPLOY_LOG, message
      ]
      Shellrunner.check_call(*args)
    end
  end
end
