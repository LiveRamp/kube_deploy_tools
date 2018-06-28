require_relative 'base'
require 'tmpdir'

module KubeDeployTools
  class PublishContainer::Driver::Gcp < PublishContainer::Driver::Base
    @gcloud_config_dir
    def authorize_command
      if check_if_activated[0].empty?
        activation_result = activate_service_account
        raise "Failed to activate service account" unless activation_result[2].success?
      end
      ['gcloud', 'docker', '-a']
    end

    # Delete temporary config dir for gcloud authentication
    def unauthorize
      Logger.info "Cleaning up authorization for #{@registry['prefix']}"
      FileUtils.rm_rf(@gcloud_config_dir) unless @gcloud_config_dir.nil?
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

    private
    # activate gcloud with svc json keys on Jenkins
    def activate_service_account
      keypath = ENV['GOOGLE_APPLICATION_CREDENTIALS']
      raise "Failed to retrieve svc key" if keypath.nil?
      # Authenticate gcloud using a tmp config dir
      @gcloud_config_dir = Dir.mktmpdir
      ENV['XDG_CONFIG_HOME'] = @gcloud_config_dir
      ENV['CLOUDSDK_CONFIG']= File.join(@gcloud_config_dir, 'gcloud')
      Shellrunner.run_call('gcloud', 'auth', 'activate-service-account', '--key-file', keypath)
    end

    def check_if_activated
      Shellrunner.run_call('gcloud', 'config', 'list', 'account', '--format', "value(core.account)")
    end
  end
end
