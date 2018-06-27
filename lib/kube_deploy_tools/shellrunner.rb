require 'forwardable'
require 'open3'
require 'shellwords'

require 'kube_deploy_tools/formatted_logger'

module KubeDeployTools
  class Shellrunner
    class << self
      extend Forwardable

      attr_accessor :shellrunner
      def_delegators :@shellrunner, :check_call, :run_call
    end

    def initialize
    end

    def check_call(*cmd, **opts)
      out, err, status = run_call(*cmd, **opts)
      if !status.success?
        raise "!!! Command failed: #{Shellwords.join(cmd)}"
      end
      out
    end

    def run_call(*cmd, **opts)
      print_cmd = opts.fetch(:print_cmd, true)
      if print_cmd
        Logger.info(Shellwords.join(cmd))
      else
        Logger.debug(Shellwords.join(cmd))
      end
      out, err, status = Open3.capture3(*cmd, stdin_data: opts[:stdin_data])
      Logger.debug(out.shellescape)

      if !status.success? && print_cmd
        Logger.warn("The following command failed: #{Shellwords.join(cmd)}")
        Logger.warn(err)
      end

      [out.chomp, err.chomp, status]
    end
  end
end

