require 'kube_deploy_tools/cluster_config'

describe 'cluster config' do
  it "gets the kube context given a target and environment" do
    username = 'fakeusername'
    allow(Etc).to receive(:getlogin).and_return(username)

    kube_context = KubeDeployTools.kube_context(
      target: 'colo-service',
      environment: 'staging',
    )
    expect(kube_context).to eq("#{username}@staging.service")
  end

  it "collects environmental Git information to create an appropriately long tag value" do
    ENV['GIT_COMMIT'] = '0981b78141b123965e7380d6021f7a9b76426290'
    ENV['GIT_BRANCH'] = 'my-testing-branch'
    ENV.delete('BUILD_ID')

    tag = KubeDeployTools.tag_from_local_env
    expect(tag).to eq('my-testing-branch-0981b78-dev')

    ENV['GIT_BRANCH'] = 'my testing! branch with some weird# characters, and also overflowing'
    ENV['BUILD_ID'] = '12345'
    tag = KubeDeployTools.tag_from_local_env
    expect(tag).to eq('my_testing__branch_with_some_weird__characters__a-0981b78-12345')
    expect(tag.size).to be <= 63
  end
end

