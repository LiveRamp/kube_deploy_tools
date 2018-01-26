require 'forwardable'
require 'logger'

require 'colorized_string'

require 'kube_deploy_tools/deferred_summary_logging'

module KubeDeployTools
  class FormattedLogger < ::Logger
    include DeferredSummaryLogging

    def self.build(context: nil, stream: $stderr)
      l = new(stream)
      l.level = level_from_env

      l.formatter = proc do |severity, datetime, _progname, msg|
        middle = context ? "[#{context}]" : ""
        colorized_line = ColorizedString.new("[#{severity}][#{datetime}]#{middle}\t#{msg}\n")

        case severity
        when "FATAL"
          ColorizedString.new("[#{severity}][#{datetime}]#{middle}\t").red + "#{msg}\n"
        when "ERROR"
          colorized_line.red
        when "WARN"
          colorized_line.yellow
        else
          colorized_line
        end
      end
      l
    end

    def self.level_from_env
      return ::Logger::DEBUG if ENV["DEBUG"]

      if ENV["LEVEL"]
        ::Logger.const_get(ENV["LEVEL"].upcase)
      else
        ::Logger::INFO
      end
    end
    private_class_method :level_from_env
  end

  class Logger
    class << self
      extend Forwardable

      attr_accessor :logger
      def_delegators :@logger, *(::Logger.public_instance_methods(false) + DeferredSummaryLogging.public_instance_methods(false))
    end
  end
end
