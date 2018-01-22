require_relative 'base'
require_relative '../image'
require 'kube_deploy_tools/shellrunner'

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

    def delete_image(repository, image, dryrun)
     if dryrun
       Logger.info("DRYRUN: delete aws repository=#{repository} region=#{@registry['region']} imageTag=#{image}")
     else
       Shellrunner.run_call('aws', 'ecr', 'batch-delete-image',
         '--repository-name', repository,
         '--region', @registry['region'],
         '--image-ids', 'imageTag=', image)
     end
    end

    private

    def get_docker_login
      args = Shellrunner.check_call('aws', 'ecr', 'get-login', '--region', @registry['region']).split

      # Remove '-e' and subsequent argument
      # This compensates for --no-include-email not being recognized in the Ubuntu packaged awscli
      # and not usable unless you upgrade
      i = args.index('-e')
      if !i.nil?
        # delete '-e'
        args.delete_at(i)
        # delete whatever value is after (usually 'none')
        args.delete_at(i)
      end

      args
    end

    def repository_exists?(repository)
      _, _, status = Shellrunner.run_call('aws', 'ecr', 'describe-repositories', '--repository-names', repository, '--region', @registry['region'])
      status.success?
    end

    def create_repository(repository)
      Shellrunner.check_call('aws', 'ecr', 'create-repository', '--repository-name', repository, '--region', @registry['region'])
    end
  end
end
