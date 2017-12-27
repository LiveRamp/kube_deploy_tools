require 'set'
require 'yaml'

module KubeDeployTools
  class BuiltArtifactsFile
    attr_accessor :build_id, :images
    def initialize(file_name)
      config = {}
      if File.exist? file_name
        config = YAML.load_file(file_name)
      end

      @images = config.fetch('images', []).to_set
      @build_id = config['build_id'] # ok to be nil
    end

    def write(file_name)
      config = {
        'build_id' => build_id,
        'images' => images.to_a
      }

      File.open(file_name, 'w') do |file|
        file.write(config.to_yaml)
      end
    end
  end
end
