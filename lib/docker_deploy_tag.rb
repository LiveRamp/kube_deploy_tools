
require 'kube_deploy_tools/shellrunner'

module KubeDeployTools
  class DockerDeployTag
    def initialize(shellrunner:)
      @shellrunner = shellrunner
    end

    def tag_images(local_prefix, remote_prefix, images, tag)
      images.each do |i|
        # TODO(joshk): allow for custom source tag? seems silly.
        local_full = "#{local_prefix}#{i}:latest"
        remote = "#{remote_prefix}#{i}:#{tag}"
        cmd = ['docker', 'tag', local_full, remote]
        @shellrunner.check_call(*cmd)
      end
    end
  end
end
