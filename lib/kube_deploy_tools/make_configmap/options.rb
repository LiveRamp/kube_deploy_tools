require 'optparse'
require 'yaml'

module KubeDeployTools
  class Options
    def options
      $options ||= begin
        res = {from_file: [], labels: {}}
        OptionParser.new do |opts|
          opts.banner = "Usage: #{opts.program_name}.rb [options]. Outputs YAML to STDOUT"

          opts.on("--name [NAME]", "ConfigMap name") do |v|
            res[:name] = v
          end

          res[:namespace] = "default"
          opts.on("--namespace [NAMESPACE]", "ConfigMap namespace") do |v|
            res[:namespace] = v
          end

          opts.on("--label [NAME=VALUE]", "ConfigMap metadata label") do |v|
            res[:labels].store(*v.split('=', 2))
          end

          opts.on("--from-file [KEYFILE]", "Key file can be specified using its file path, in which case file basename will be used as
    configmap key, or optionally with a key and file path, in which case the given key will be used.  Specifying a directory
    will iterate each named file in the directory whose basename is a valid configmap key.") do |v|
            res[:from_file] << v
          end
        end.parse!

        raise "no name given" unless res[:name].strip != ''
        raise "no files given" if res[:from_file].empty?

        res
      end
    end
  end
end