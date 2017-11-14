require 'optparse'
require 'yaml'

module KubeDeployTools
  class Options
    def options
      $options ||= begin
        res = {from_file: []}
        OptionParser.new do |opts|
          opts.banner = "Usage: #{opts.program_name}.rb [options]. Outputs YAML to STDOUT"

          opts.on("--name [NAME]", "ConfigMap name") do |v|
            res[:name] = v
          end

          res[:namespace] = "default"
          opts.on("--namespace [NAMESPACE]", "ConfigMap namespace") do |v|
            res[:namespace] = v
          end

          opts.on("--from-file [FILE]", "File for map (can be provided multiple times)") do |v|
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