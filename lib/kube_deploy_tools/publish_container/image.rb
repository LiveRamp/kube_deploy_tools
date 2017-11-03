module KubeDeployTools
  class PublishContainer
    class Image
      attr_accessor :registry, :repository, :tag
      def initialize(registry, repository, tag)
        registry += '/' unless registry.end_with?('/')
        @registry = registry
        @repository = repository
        @tag = tag
      end

      def full_tag
        "#{registry}#{repository}:#{tag}"
      end
    end
  end
end
