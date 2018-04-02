require 'kube_deploy_tools/version'

module KubeDeployTools
  class Kdt
    attr_reader :path, :args

    DESCRIPTIONS = {
        'deploy'              => 'Releases all Kubernetes resources in a deploy artifact with |kubectl apply|',
        'make_configmap'      => 'Creates a new ConfigMap, alternative to |kubectl create configmap|',
        'publish_container'   => 'Tags and pushes images with to our image registries',
        'render_deploys'      => 'Renders ERB templates',
        'render_deploys_hook' => 'The default hook used by render_deploys that uses templater to render Kubernetes manifests from the kubernetes/ directory into the build/kubernetes/ directory',
        'sweeper'             => 'Cleans up images and artifacts in our image and artifact repositories',
        'templater'           => 'Renders ERB templates into Kubernetes manifests with a context defined in YAML'
    }

    def initialize(path, args)
        @path = path
        @args = args
    end

    def bins_names
        @bins ||= Dir["#{path}/*"].map { |x| File.basename(x) } - ['kdt']
    end

    def bin
      args.first
    end

    def display_bins
      # Print full runtime version
      puts Gem.loaded_specs["kube_deploy_tools"].version

      bins_names.each do |bin|
          spaces_count = 25 - bin.size
          puts "-> #{bin}#{' ' * spaces_count}| #{DESCRIPTIONS[bin]}"
      end
    end

    def execute!
      raise "command '#{bin}' is not a valid command" unless valid_bin?
      bin_with_path = "#{path}/#{bin}"
      bin_args = args[1..-1]

      # calling exec with multiple args will prevent shell expansion
      # https://ruby-doc.org/core/Kernel.html#method-i-exec
      exec bin_with_path, *bin_args
    end

    def valid_bin?
      bins_names.include?(bin)
    end
  end
end
