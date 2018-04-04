require 'set'
require 'yaml'

module KubeDeployTools
  class BuiltArtifactsFile
    attr_accessor :build_id, :images, :extra_files

    def initialize(file)
      config = {}
      if File.exist? file and YAML.load_file file
        config = YAML.load_file(file)
      end

      @images = config.fetch('images', []).to_set
      @extra_files = config.fetch('extra_files', []).to_set
      @build_id = config['build_id'] # ok to be nil
    end

    def write(file)
      config = {
        'build_id' => build_id,
        'extra_files' => extra_files.to_a,
        'images' => images.to_a
      }
      file.write(config.to_yaml)
    end
  end
end
