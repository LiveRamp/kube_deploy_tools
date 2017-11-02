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
      # Save the entire stdout and stderr output of the subprocess
      # to return at the end
      out = ''
      err = ''

      # Stream stdout and stderr output of the subprocess
      # Makes logs appear in realtime for long running processes
      status = Open3.popen3(*cmd) do |stdin, stdout, stderr, thread|
        # read each stream from a new thread
        { :out => stdout, :err => stderr }.each do |key, stream|
          Thread.new do
            until (line = stream.gets).nil? do
              if key == :out
                @logger.debug line.strip
                out << line
              else
                @logger.warn line.strip
                err << line
              end
            end
          end
        end

        thread.join
        thread.value
      end


      if !status.success?
        @logger.warn("The following command failed: #{Shellwords.join(cmd)}")
        @logger.warn(err)
      end

      [out.chomp, err.chomp, status]
    end
  end
end

