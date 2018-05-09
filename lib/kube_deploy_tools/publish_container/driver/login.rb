require_relative 'base'
require_relative '../image'

module KubeDeployTools
  class PublishContainer::Driver::Login < PublishContainer::Driver::Base
    # This driver expects the following to be set in the @registry hash:
    # username_var: set to a string which is the env var containing the docker
    # registry username
    # password_var: set to a string which is the env var containing the docker
    # registry password
    # prefix: passed directly to docker login
    def authorize_command
      ['docker', 'login', '--username', ENV.fetch(@registry['username_var']),
       '--password', ENV.fetch(@registry['password_var']), @registry['prefix']]
    end

    def delete_image(repository, image, dryrun)
      raise 'not implemented'
    end
  end
end
