require_relative 'base'
require_relative '../image'

module KubeDeployTools
  class PublishContainer::Driver::Aws < PublishContainer::Driver::Base
    def push_image(image)
      create_repository(image.repository) unless repository_exists?(image.repository)
      super(image)
    end

    def authorize_command
      login_cmd = get_docker_login
      raise "Unexpected login command: #{login_cmd}" if login_cmd.first(2) != ['docker', 'login']
      login_cmd
    end

    private

    def get_docker_login
      @shellrunner.check_call('aws', 'ecr', 'get-login', '--no-include-email', '--region', @registry['region']).split
    end

    def repository_exists?(repository)
      _, _, status = @shellrunner.run_call('aws', 'ecr', 'describe-repositories', '--repository-names', repository, '--region', @registry['region'])
      status.success?
    end

    def create_repository(repository)
      @shellrunner.check_call('aws', 'ecr', 'create-repository', '--repository-name', repository, '--region', @registry['region'])
    end
  end
end
