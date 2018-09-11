require 'kube_deploy_tools/object'
require 'optparse'

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
      res['metadata']['labels'] = @labels if @labels
      @from_file.each do |from_file|
        if from_file.include? '='
          # e.g. --from-file=config.yml=/path/to/configs/production.yml
          configmap_key, filepath = from_file.split("=", 2)
          res['data'][configmap_key] = File.read(filepath)
        elsif File.file?(from_file)
          # e.g. --from-file=/path/to/configs/production.yml
          configmap_key = File.basename(from_file)
          filepath = from_file
          res['data'][configmap_key] = File.read(filepath)
        elsif File.directory?(from_file)
          # e.g. --from-file=/path/to/configs/
          Dir[File.join(from_file, '*')].each do |filepath|
            # NOTE(jmodes): Multiple levels of directories are not supported.
            next if File.directory?(filepath)
            configmap_key = File.basename(filepath)
            res['data'][configmap_key] = File.read(filepath)
          end
        end
      end
      res
    end
  end
end
