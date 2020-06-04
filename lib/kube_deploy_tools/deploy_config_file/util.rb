require 'tempfile'

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

    def load_library(lib)
      # All paths must be valid accessible gcs paths for the current user.
      # To modify gcloud identity being used by this process, set
      # GOOGLE_APPLICATION_CREDENTIALS or sign in with `gcloud auth login`
      lib_config = nil
      if lib.start_with?('gs://')
        Tempfile.open(['gs-kdt-library', '.yaml']) do |t|
          out = Shellrunner.check_call('gsutil', 'cat', lib)
          t.write(out)
          t.flush
          lib_config = DeployConfigFile.new(t.path)
        end
      elsif File.exist?(lib)
        lib_config = DeployConfigFile.new(lib)
      else
        raise "Unsupported or non-existent library: #{lib}"
      end

      lib_config
    end
  end
end
