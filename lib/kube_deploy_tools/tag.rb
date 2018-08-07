module KubeDeployTools
  # Default method to derive a tag name.
  # An image is tagged for the git sha.
  def self.tag_from_local_env
    codestamp = `git describe --always --abbrev=7 --match=NONE --dirty`

    # Definition of a valid image tag via:
    # https://docs.docker.com/engine/reference/commandline/tag/#extended-description:
    #
    # > A tag name must be valid ASCII and may contain lowercase and uppercase
    # > letters, digits, underscores, periods and dashes.
    # > A tag name may not start with a period or a dash and
    # > may contain a maximum of 128 characters.
    #
    # Regex for a valid image tag via:
    # https://github.com/docker/distribution/blob/749f6afb4572201e3c37325d0ffedb6f32be8950/reference/regexp.go#L37
    docker_tag = codestamp.scan(/[\w][\w.-]{0,127}/).first

    if docker_tag.nil?
      raise "Expected valid Docker tag, but received '#{codestamp}'"
    end

    "#{docker_tag}"
  end
end
