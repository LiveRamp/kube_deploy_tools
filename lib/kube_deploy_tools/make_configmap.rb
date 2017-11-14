require 'yaml'
require 'kube_deploy_tools/object'
require 'optparse'
require 'fileutils'

module KubeDeployTools

  class ConfigMap
    def initialize(name, namespace, from_file)
      @name = name
      @namespace = namespace
      @from_file = from_file
    end

    def base 
      {
        'apiVersion' => 'v1',
        'kind' => 'ConfigMap',
        'metadata' => {},
        'data' => {}
      }
    end

    def target_hash
      res = base
      res['metadata']['name'] = @name
      res['metadata']['namespace'] = @namespace
      @from_file.each do |maybeFile|
        if File.file?(maybeFile)
          res['data'][File.basename(maybeFile)] = File.read(maybeFile)
        elsif File.directory?(maybeFile)
          Dir[File.join(maybeFile, '*')].each do |file|
            next if File.directory?(file)
            res['data'][File.basename(file)] = File.read(file)
          end
        end
      end
      res
    end
  end
end            