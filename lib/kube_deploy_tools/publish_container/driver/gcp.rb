require_relative 'base'

module KubeDeployTools
  class PublishContainer::Driver::Gcp < PublishContainer::Driver::Base
    def authorize_command
      ['gcloud', 'docker', '-a']
    end
  end
end
