require 'json'

require_relative 'base'
require_relative '../image'
require 'kube_deploy_tools/shellrunner'

module KubeDeployTools
  class ImageRegistry::Driver::Aws < ImageRegistry::Driver::Base
    def push_image(image)
      create_repository(image.repository) unless repository_exists?(image.repository)
      super(image)
    end

    def authorize_command
      login_cmd = get_docker_login
      raise "Unexpected login command: #{login_cmd}" if login_cmd.first(2) != ['docker', 'login']
      login_cmd
    end

    def unauthorize
    end

    def delete_image(image, dryrun)
      # In the AWS driver, the 'delete many' primitive is the primary one.
      delete_images([image], dryrun)
    end

    def delete_images(images, dryrun)
      # Aggregate images by repository and call aws ecr batch-delete-image
      # once per repository.
      ids_by_repository = {}
      images.each do |image|
        repository, tag = split_full_image_id(image)
        item = {'imageTag': tag}
        if ids_by_repository[repository].nil?
          ids_by_repository[repository] = [item]
        else
          ids_by_repository[repository].push(item)
        end
      end

      # JSON format documented here:
      # https://docs.aws.amazon.com/cli/latest/reference/ecr/batch-delete-image.html
      ids_by_repository.each do |repository, image_ids|
        # batch-delete-image has a threshold of 100 image_ids at a time
        image_chunks = image_ids.each_slice(100).to_a

        image_chunks.each do |images|
          cmd = [
            'aws', 'ecr', 'batch-delete-image',
            '--repository-name', repository,
            '--region', @registry.config.fetch('region'),
            '--image-ids', images.to_json,
          ]

          if dryrun
            Logger.info("Would run: #{cmd}")
          else
            Shellrunner.check_call(*cmd)
          end
        end
      end
    end

    private
    def get_docker_login
      args = Shellrunner.check_call('aws', 'ecr', 'get-login', '--region', @registry.config.fetch('region')).split

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
      _, _, status = Shellrunner.run_call('aws', 'ecr', 'describe-repositories', '--repository-names', repository, '--region', @registry.config.fetch('region'))
      status.success?
    end

    def create_repository(repository)
      Shellrunner.check_call('aws', 'ecr', 'create-repository', '--repository-name', repository, '--region', @registry.config.fetch('region'))
    end

    def split_full_image_id(image_id)
      # Create syntax suitable for aws ecr subcommand.
      # Example: 12345678.dkr.ecr.amazonaws.com/my_app:deadbeef-123
      # splits into ('my_app', 'deadbeef-123') after verifying that the
      # prefix is the expected one for this driver instance.
      repo_with_prefix, tag = image_id.split(':', 2)
      prefix, repository = repo_with_prefix.split('/', 2)

      # Sanity check, as the resultant command line uses the region to specify
      # the prefix implicitly.
      raise "This driver can't delete images from #{prefix}, only #{@registry.prefix}" unless prefix == @registry.prefix

      return repository, tag
    end
  end
end
