require 'shellwords'
require 'open3'

module KubeDeployTools
  class Shellrunner
    def initialize(logger:)
      @logger = logger
    end

    def check_call(*cmd)
      out, err, status = run_call(*cmd)
      if !status.success?
        raise "!!! Command failed: #{Shellwords.join(cmd)}"
      end
    end

    def run_call(*cmd)
      @logger.info(Shellwords.join(cmd))
      out, err, status = Open3.capture3(*cmd)
      @logger.debug(out.shellescape)

      if !status.success?
        @logger.warn("The following command failed: #{Shellwords.join(cmd)}")
        @logger.warn(err)
      end

      [out.chomp, err.chomp, status]
    end
  end
end

