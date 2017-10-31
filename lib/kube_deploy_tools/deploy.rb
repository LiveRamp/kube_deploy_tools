require 'yaml'
require 'kube_deploy_tools/errors'
require 'kube_deploy_tools/kubernetes_resource'

# NOTE(jmodes): the order matters, and predeploy resources will be deployed
# in order.
# e.g. Namespaces will be deployed before Services and ConfigMaps, which
# are namespaced resources that may depend on deploying Namespaces first.
PREDEPLOY_RESOURCES = [
  "Namespace",
  "StorageClass",
  "CustomResourceDefinition",
  "ThirdPartyResource",
  "ConfigMap",
  "Service",
]

module KubeDeployTools
  class Deploy
    def initialize(
      logger:,
      kubectl:,

      input_path:)
      @logger = logger
      @kubectl = kubectl

      @input_path = input_path
    end

    def run(dry_run: true)
      if dry_run == true
        @logger.info("Running in dry-run mode")
      end
      resources = read_resources

      # Deploy predeploy resources first, in order.
      # Then deploy the remaining resources in any order.
      deploy_resources = resources
        .sort { |a,b|
          # NOTE(jmodes): we want the comparison below, but with a nil check
          # PREDEPLOY_RESOURCES.index(a.content["kind"]) <=> PREDEPLOY_RESOURCES.index(b.content["kind"])
          # https://stackoverflow.com/a/808721
          idx_a = PREDEPLOY_RESOURCES.index(a.content["kind"])
          idx_b = PREDEPLOY_RESOURCES.index(b.content["kind"])
          idx_a && idx_b ? idx_a <=> idx_b : idx_a ? -1 : 1
        }

      kubectl_apply(deploy_resources, dry_run: dry_run)
    end

    def read_resources
      resources = []

      # Recursively read
      Dir[ File.join(@input_path, '**', '*') ].each do |filepath|
        next unless filepath.end_with?(".yml", ".yaml")

        read_resource_content(filepath) do |resource_content|
          resource = KubeDeployTools::KubernetesResource.new(
            filepath: filepath,
            content: resource_content,
          )

          resources << resource
        end
      end

      resources
    end

    def read_resource_content(filepath)
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
      @logger.debug(debug_msg)
      raise FatalDeploymentError, "Template '#{filepath}' cannot be parsed"
    end

    def kubectl_apply(resources, dry_run: true)
      resources.each do |resource|
        args = ['apply', '-f', resource.filepath, "--dry-run=#{dry_run}"]
        out, err, status = @kubectl.run(*args)
        if !status.success?
          raise FatalDeploymentError, "Failed to apply resource '#{resource.filepath}'"
        else
          @logger.info(out)
        end
      end
    end
  end
end

