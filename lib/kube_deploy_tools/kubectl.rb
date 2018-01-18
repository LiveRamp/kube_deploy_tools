require 'kube_deploy_tools/object'
require 'kube_deploy_tools/shellrunner'

module KubeDeployTools
  class Kubectl
    def initialize(
      context:,
      kubeconfig:)
      @context = context
      @kubeconfig = kubeconfig

      raise ArgumentError, "context is required" if context.empty?
    end

    def run(*args, print_cmd: true, timeout: nil)
      args = args.unshift("kubectl")
      args.push("--context=#{@context}")
      args.push("--kubeconfig=#{@kubeconfig}") if @kubeconfig.present?
      args.push("--request-timeout=#{timeout}") if timeout.present?

      Shellrunner.run_call(*args, print_cmd: print_cmd)
    end

  end
end
