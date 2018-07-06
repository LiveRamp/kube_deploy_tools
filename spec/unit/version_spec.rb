require 'kube_deploy_tools/version'


describe KubeDeployTools do
  it 'sets the version for a Jenkins master or release build' do
    ENV['GIT_BRANCH'] = 'origin/master'
    ENV['BUILD_ID'] = '5678'
    actual = KubeDeployTools.version_xyz
    expect(actual).to end_with('.' + ENV['BUILD_ID'])

    ENV['GIT_BRANCH'] = 'origin/release-2.0'
    ENV['BUILD_ID'] = '5678'
    actual = KubeDeployTools.version_xyz
    expect(actual).to end_with('.' + ENV['BUILD_ID'])
  end

  it 'sets the version for a Jenkins non-master build' do
    ENV['GIT_BRANCH'] = 'origin/my-pr-branch'
    ENV['BUILD_ID'] = '5678'
    actual = KubeDeployTools.version_xyz
    expect(actual).to end_with('.dev-' + ENV['BUILD_ID'])
  end

  it 'sets the version for a non-Jenkins build' do
    ENV['GIT_BRANCH'] = nil
    ENV['BUILD_ID'] = nil
    actual = KubeDeployTools.version_xyz
    expect(actual).to end_with('.dev')
  end
end
