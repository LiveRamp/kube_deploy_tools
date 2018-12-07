
module KubeDeployTools
  module DeployConfigFileUtil
    def check_and_err(condition, error)
      if ! condition
        Logger.error("Error in configuration #{@filename}")
        raise ArgumentError, error
      end
    end

    def check_and_warn(condition, warning)
      if ! condition
        Logger.warn("Warning in configuration #{@filename}")
        Logger.warn(warning)
      end
    end
  end
end
