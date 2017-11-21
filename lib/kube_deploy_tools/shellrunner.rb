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
      out
    end

    def run_call(*cmd, print_cmd: true)
      if print_cmd
        @logger.info(Shellwords.join(cmd))
      else
        @logger.debug(Shellwords.join(cmd))
      end

      out, err, status = Open3.capture3(*cmd)
      @logger.debug(out.shellescape)

      if !status.success?
        @logger.warn("The following command failed: #{Shellwords.join(cmd)}") if print_cmd
        @logger.warn(err) if print_cmd
      end

      [out.chomp, err.chomp, status]
    end
  end
end

