require 'kube_deploy_tools/version'

describe KubeDeployTools do
  it 'sets the version for a Jenkins master or release build' do
    ENV['GIT_BRANCH'] = 'origin/master'
    ENV['BUILD_ID'] = '5678'
    actual = KubeDeployTools.version_xyz

    # Must be a valid Gem version
    expect(Gem::Version.correct?(actual)).to be_truthy
    actual_gem_version = Gem::Version.new(actual)

    expect(actual_gem_version.prerelease?).to be_falsey
    expect(actual_gem_version).to eq(actual_gem_version.release())

    ENV['GIT_BRANCH'] = 'origin/release-2.0'
    ENV['BUILD_ID'] = '5678'

    # Must be a valid Gem version
    actual = KubeDeployTools.version_xyz
    expect(Gem::Version.correct?(actual)).to be_truthy

    actual_gem_version = Gem::Version.new(actual)
    expect(actual_gem_version.prerelease?).to be_falsey
    expect(actual_gem_version).to eq(actual_gem_version.release())
  end

  it 'sets the version for a Jenkins non-master build' do
    ENV['GIT_BRANCH'] = 'origin/my-pr-branch_with_long_name'
    ENV['BUILD_ID'] = '5678'
    actual = KubeDeployTools.version_xyz

    # Must be a valid Gem version
    puts actual
    expect(Gem::Version.correct?(actual)).to be_truthy
    actual_gem_version = Gem::Version.new(actual)

    expect(actual_gem_version.prerelease?).to be_truthy
    expect(actual_gem_version).not_to eq(actual_gem_version.release())

    # contain prerelease version notation
    expect(actual).to match(/dev/)
    # contain build metadata
    expect(actual).to match(/5678/)
  end

  it 'sets the version for a non-Jenkins build' do
    ENV['GIT_BRANCH'] = nil
    ENV['BUILD_ID'] = nil
    actual = KubeDeployTools.version_xyz
    expect(Gem::Version.correct?(actual)).to be_truthy
    actual_gem_version = Gem::Version.new(actual)
    expect(actual_gem_version.prerelease?).to be_truthy
    expect(actual_gem_version).not_to eq(actual_gem_version.release())

    # contain prerelease version notation
    expect(actual).to match(/dev/)
  end
end
