module KubeDeployTools
  VERSION_XY = "1.4"
  def self.version_xyz
    version_xyz = VERSION_XY
    version_xyz += '.'
    if ENV.fetch('GIT_BRANCH', '').end_with?('/master')
      # Jenkins master builds
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
