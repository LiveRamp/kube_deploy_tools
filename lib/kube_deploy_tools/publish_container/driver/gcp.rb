require_relative 'base'

module KubeDeployTools
  class PublishContainer::Driver::Gcp < PublishContainer::Driver::Base
    def authorize_command
      ['gcloud', 'docker', '-a']
    end

    def delete_image(image_id, dryrun)
      # Need the id path to be [HOSTNAME]/[PROJECT-ID]/[IMAGE]
      if dryrun
        Logger.info("DRYRUN: delete gcp image #{image_id}")
      else
        # --quiet removes the user-input component
        Shellrunner.run_call('gcloud', 'container', 'images', 'delete', '--quiet', image_id, '--force-delete-tags')
      end
    end
  end
end
