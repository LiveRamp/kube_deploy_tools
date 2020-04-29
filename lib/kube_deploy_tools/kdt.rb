require 'kube_deploy_tools/version'

module KubeDeployTools
  class Kdt
    DESCRIPTIONS = {
      'deploy'   => 'Releases all Kubernetes resources in a deploy artifact with |kubectl apply|',
      'push'     => 'Tags and pushes images to defined image registries',
      'generate' => 'Generates artifacts based on templates in kubernetes/ and your deploy.yaml.',
      'publish'  => 'Publishes generated artifacts to your artifact store.',
      'upgrade'   => 'Upgrades a KDT 1.x deploy.yml to a KDT 2.x deploy.yaml',

      # Deprecated entrypoints (will go away soon)
      'make_configmap'      => 'DISAPPEARING. Creates a new ConfigMap, alternative to |kubectl create configmap|',
      'templater'           => 'DISAPPEARING. Renders ERB templates into Kubernetes manifests with a context defined in YAML',
      'render_deploys_hook' => 'DISAPPEARING. The default hook used by render_deploys that uses templater to render Kubernetes manifests from the kubernetes/ directory into the build/kubernetes/ directory',
    }

    MAPPINGS = {
      'render_deploys'    => 'generate',
      'publish_artifacts' => 'publish',
      'publish_container' => 'push',
    }

    def initialize(path, args)
      KubeDeployTools::Logger.logger = KubeDeployTools::FormattedLogger.build

      @path = path
      @args = args
    end

    def bins_names
      @bins ||= Dir["#{@path}/*"].map { |x| File.basename(x) } - ['kdt']
    end

    def display_bins
      # Print full runtime version
      version = Gem.loaded_specs["kube_deploy_tools"].version
      puts "kube_deploy_tools #{version}"

      bins_names.each do |bin|
        spaces_count = 25 - bin.size
        puts "-> #{bin}#{' ' * spaces_count}| #{DESCRIPTIONS[bin]}"
      end
    end

    def execute!
      bin = @args.first
      if MAPPINGS.member?(bin)
        new_bin = MAPPINGS.fetch(bin)
        Logger.warn("The `kdt #{bin}` subcommand is going away in a future version. Use `kdt #{new_bin}` instead.")
        bin = new_bin
      end

      raise "command '#{bin}' is not a valid command" unless valid_bin?(bin)
      bin_with_path = "#{@path}/#{bin}"
      bin_args = @args[1..-1]

      # calling exec with multiple args will prevent shell expansion
      # https://ruby-doc.org/core/Kernel.html#method-i-exec
      exec bin_with_path, *bin_args
    end

    def valid_bin?(bin)
      bins_names.include?(bin)
    end
  end
end
