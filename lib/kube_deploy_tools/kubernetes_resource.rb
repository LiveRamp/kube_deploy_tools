require 'tempfile'

module KubeDeployTools
  class KubernetesResource
    attr_accessor :definition,
      :kind,
      :name,
      :namespace

    def self.build(filepath: nil, definition:, kubectl:)
      opts = { filepath: filepath, definition: definition, kubectl: kubectl }
      # Find the corresponding class for the Kubernetes resource, if available
      if ["Deployment"].include?(definition["kind"])
        klass = KubeDeployTools.const_get(definition["kind"])
        klass.new(**opts)
      else
        # Otherwise initialize here if no class exists for this Kubernetes
        # resource kind
        inst = new(**opts)
        inst.kind = definition["kind"]
        inst
      end
    end

    def initialize(filepath:, definition:, kubectl:)
      @filepath = filepath
      @definition = definition
      @kubectl = kubectl

      @namespace = definition.dig('metadata', 'namespace')
      @name = definition.dig('metadata', 'name')
      @kind = definition['kind']
    end

    def filepath
      @filepath ||= file.path
    end

    def file
      @file ||= create_definition_tempfile
    end

    def create_definition_tempfile
      file = Tempfile.new(["#{@namespace}-#{@kind}-#{@name}", ".yaml"])
      file.write(YAML.dump(@definition))
      file
    ensure
      file&.close
    end

    def sync
      # unimplemented
    end
  end
end
