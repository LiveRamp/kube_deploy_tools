module KubeDeployTools
  class KubernetesResource
    attr_accessor :filepath,
      :content

    def initialize(filepath:, content:)
      @filepath = filepath
      @content = content
    end
  end
end
