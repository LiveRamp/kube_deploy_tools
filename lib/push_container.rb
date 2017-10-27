require 'cluster_config'
require 'util'

module PushContainer
  def self.publish(local_prefix, registry_name, images, tag)
    registry = REGISTRIES[registry_name]

    images.each do |i|
      local_full = "#{local_prefix}#{i}:latest"
      remote = "#{remote_prefix}#{i}:#{tag}"
      cmd = ['docker', 'tag', local_full, remote]
      check_call(cmd)
    end

    if registry['push']
      # Does whatever is necessary to authorize against this registry
      # using |push_auth| parameters.
      PushContainer.authorize(registry)

      # Push a single container (images[0]) under the assumption that
      # most containers in this pass are built on a similar image.
      PushContainer.push_images(registry, [images[0]])

      # Push the rest of the containers (images[1..-1]) in parallel
      if images.size > 1
        PushContainer.push_images(registry, images[1..-1])
      end
    end
  end

  def self.push_images(images)
    # Pushes |images| in parallel using 'docker push', assuming that all
    # authorization has already occurred.
    raise 'not implemented'
  end

  def self.authorize(registry)
    raise 'not implemented'
  end
end
