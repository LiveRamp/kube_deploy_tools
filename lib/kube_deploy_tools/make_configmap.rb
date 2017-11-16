require 'yaml'
require 'kube_deploy_tools/object'
require 'optparse'
require 'fileutils'

module KubeDeployTools

  class ConfigMap
    def initialize(name, from_file, namespace = 'default', labels = nil)
      @name = name
      @namespace = namespace
      @labels = labels
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
      res['metadata']['labels'] = @labels
      @from_file.each do |maybeFile|
        if maybeFile.include? '='
          # e.g. --from-file=config.yml=/path/to/configs/production.yml
          configmap_key, filepath = maybeFile.split("=", 2)
          res['data'][configmap_key] = File.read(filepath)
        elsif File.file?(maybeFile)
          configmap_key = File.basename(maybeFile)
          filepath = maybeFile
          res['data'][configmap_key] = File.read(filepath)
        elsif File.directory?(maybeFile)
          # e.g. --from-file=/path/to/configs/
          Dir[File.join(maybeFile, '*')].each do |filepath|
            # NOTE(jmodes): Multiple levels of directories are not supported.
            next if File.directory?(filepath)
            res['data'][configmap_key] = File.read(filepath)
          end
        end
      end
      res
    end
  end
end