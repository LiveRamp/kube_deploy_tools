require 'kube_deploy_tools/object'

module KubeDeployTools
  class Kubectl
    def initialize(
      # Dependencies
      shellrunner:,

      context:,
      kubeconfig:)
      @context = context
      @kubeconfig = kubeconfig
      @shellrunner = shellrunner

      raise ArgumentError, "context is required" if context.empty?
    end

    def run(*args, print_cmd: true)
      args = args.unshift("kubectl")
      args.push("--context=#{@context}")
      args.push("--kubeconfig=#{@kubeconfig}") if @kubeconfig.present?

      @shellrunner.run_call(*args, print_cmd: print_cmd)
    end

  end
end
