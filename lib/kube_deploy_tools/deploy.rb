require 'set'
require 'yaml'
require 'kube_deploy_tools/errors'
require 'kube_deploy_tools/formatted_logger'
require 'kube_deploy_tools/shellrunner'
require 'kube_deploy_tools/kubernetes_resource'
require 'kube_deploy_tools/kubernetes_resource/deployment'
require 'kube_deploy_tools/concurrency'

# NOTE(jmodes): the order matters, and predeploy resources will be deployed
# in order.
# e.g. Namespaces will be deployed before Services and ConfigMaps, which
# are namespaced resources that may depend on deploying Namespaces first.
PREDEPLOY_RESOURCES = [
  "Namespace",
  "StorageClass",
  "ServiceAccount",
  "ClusterRole",
  "Role",
  "ClusterRoleBinding",
  "RoleBinding",
  "CustomResourceDefinition",
  "ThirdPartyResource",
  "ConfigMap",
  "Service",
]

module KubeDeployTools
  class Deploy
    def initialize(
      kubectl:,
      input_path:,
      glob_files: [Hash['include_files'=> '**/*']]
      )
      @kubectl = kubectl
      @input_path = input_path
      @glob_files = glob_files
    end

    def run(dry_run: true)
      Logger.reset
      Logger.phase_heading("Initializing deploy")
      if dry_run == true
        Logger.warn("Running in dry-run mode")
      end
      resources = read_resources(select_resources(@glob_files))

      Logger.phase_heading("Checking initial resource statuses")
      KubernetesDeploy::Concurrency.split_across_threads(resources, &:sync)

      Logger.phase_heading("Checking deployment replicas match")
      deployments = resources
        .select { |resource| resource.definition["kind"] == 'Deployment' }
      KubernetesDeploy::Concurrency.split_across_threads(deployments, &:warn_replicas_mismatch)

      Logger.phase_heading("Deploying all resources")
      # Deploy predeploy resources first, in order.
      # Then deploy the remaining resources in any order.
      deploy_resources = resources
        .sort { |a,b|
          # NOTE(jmodes): we want the comparison below, but with a nil check
          # PREDEPLOY_RESOURCES.index(a.definition["kind"]) <=> PREDEPLOY_RESOURCES.index(b.definition["kind"])
          # https://stackoverflow.com/a/808721
          idx_a = PREDEPLOY_RESOURCES.index(a.definition["kind"])
          idx_b = PREDEPLOY_RESOURCES.index(b.definition["kind"])
          idx_a && idx_b ? idx_a <=> idx_b : idx_a ? -1 : 1
        }

      kubectl_apply(deploy_resources, dry_run: dry_run)

      success = true
    ensure
      Logger.print_summary(success)
      status = success ? "success" : "failed"
      success
    end

    def read_resources(filtered_files = Dir[ File.join(@input_path, '**', '*') ])
      resources = []
      filtered_files.each do |filepath|
        next unless filepath.end_with?(".yml", ".yaml")
        read_resource_definition(filepath) do |resource_definition|
          resource = KubeDeployTools::KubernetesResource.build(
            filepath: filepath,
            definition: resource_definition,
            kubectl: @kubectl,
          )
          resources << resource
        end
      end
      resources
    end

    # Load corresponding resource files filtered by include and exlude tags
    def select_resources(glob_files)
      all_files = Dir[File.join(@input_path, '**', '*')].to_set
      filtered_files = if glob_files.any? { |e| e.has_key?("include_files")}
        Set.new
      else
        Set.new(all_files)
      end

      glob_files.each do |gf|
        if gf.has_key?("include_files")
          filtered_files.merge( all_files.select{ |f| File.fnmatch?(gf["include_files"], f, File::FNM_PATHNAME) } )
        else
          filtered_files.reject!{ |f| File.fnmatch?(gf["exclude_files"], f, File::FNM_PATHNAME) }
        end
      end
      filtered_files
    end

    def read_resource_definition(filepath)
      file_content = File.read(filepath)
      YAML.load_stream(file_content) do |doc|
        yield doc unless doc.empty?
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
        args = ['apply', '-f', resource.filepath, "--dry-run=#{dry_run}"]
        out, err, status = @kubectl.run(*args)
        if !status.success?
          raise FatalDeploymentError, "Failed to apply resource '#{resource.filepath}'"
        else
          Logger.info(out)
        end
      end
    end
  end
end
