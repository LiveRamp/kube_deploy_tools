module KubeDeployTools
  # NOTE(jmodes): Bump patch
  VERSION_XYZ = '2.1.22'
  def self.version_xyz
    version_xyz = VERSION_XYZ
    prerelease_notation = '.dev'
    build_metadata_notation = ''
    build_metadata_notation += ENV.has_key?('GIT_BRANCH') ? '.' + ENV.fetch('GIT_BRANCH') : ''
    build_metadata_notation += ENV.has_key?('BUILD_ID') ? '.' + ENV.fetch('BUILD_ID') : ''
    build_metadata_notation = build_metadata_notation.sub('origin/', '')
    build_metadata_notation = build_metadata_notation.gsub('_', '-')

    branch = ENV.fetch('GIT_BRANCH', '').sub('origin/', '')
    if branch == 'master' || branch.start_with?('release')
      # Jenkins master or release builds
      return version_xyz
    elsif ENV.has_key?('GIT_BRANCH') && ENV.has_key?('BUILD_ID')
      # Jenkins non-master builds
      version_xyz += prerelease_notation + build_metadata_notation
    elsif File.exist?('/proc/1/cgroup') && File.open('/proc/1/cgroup').grep(/docker/).any?
      # Docker builds
      return version_xyz
    else
      # non-Jenkins
      version_xyz += prerelease_notation
    end
  end
end
