require_relative 'base'

module KubeDeployTools
  class PublishContainer::Driver::Gcp < PublishContainer::Driver::Base
    def authorize_command
      ['gcloud', 'docker', '-a']
    end

    def delete_image(image_id, dryrun: false)
      # Need the id path to be [HOSTNAME]/[PROJECT-ID]/[IMAGE]
      if dryrun
        @logger.info("Would delete gcp image: image=#{image_id}")
      else
        @shellrunner.run_call('gcloud', 'container', 'images', 'delete', image_id)
      end
    end
  end
end
