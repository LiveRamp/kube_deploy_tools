module KubeDeployTools
  VERSION_XY = "2.0"
  def self.version_xyz
    version_xyz = VERSION_XY
    version_xyz += '.'

    branch = ENV.fetch('GIT_BRANCH', '').sub('origin/', '')
    if branch == 'master' || branch.start_with?('release')
      # Jenkins master or release builds
      version_xyz += ENV.fetch('BUILD_ID')
    elsif ENV.has_key?('GIT_BRANCH')
      # Jenkins non-master builds
      version_xyz += "dev-#{ENV.fetch('BUILD_ID')}"
    else
      # non-Jenkins
      version_xyz += 'dev'
    end
  end
end
