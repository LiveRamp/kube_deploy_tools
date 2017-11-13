require 'json'

require 'kube_deploy_tools/object'

module KubeDeployTools
  class Deployment < KubernetesResource
    attr_accessor :found,
      :local_replicas,
      :remote_replicas,
      :recorded_replicas

    def sync
      @local_replicas = @definition["spec"]["replicas"]

      raw_json, _err, st = @kubectl.run("get", "-f", filepath, "--output=json", print_cmd: false)
      @found = st.success?

      if st.success?
        deployment_data = JSON.parse(raw_json)
        @remote_replicas = deployment_data["spec"]["replicas"]
      end

      raw_json, _err, st = @kubectl.run("apply", "view-last-applied", "-f", filepath, "--output=json", print_cmd: false)
      if st.success?
        deployment_data = JSON.parse(raw_json)
        @recorded_replicas = deployment_data["spec"]["replicas"]
      end
    end

    def warn_replicas_mismatch
      if @found
        if @local_replicas.present? && @local_replicas.to_i != @remote_replicas.to_i
          warning = "Deployment replica count mismatch! Will scale deployment/#{@name} from #{@remote_replicas} to #{@local_replicas}"
          @logger.warn(warning)
        elsif @local_replicas.nil? && !@recorded_replicas.nil?
          # Check if we're converting to a replicaless Deployment
          warning = "Deployment replica count mismatch! Will scale deployment/#{@name} from #{@remote_replicas} to 1. Run `kubectl apply set-last-applied -f #{@filepath}` first."
          @logger.warn(warning)
        end
      end
    end
  end
end
