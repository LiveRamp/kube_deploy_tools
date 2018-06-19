require 'kube_deploy_tools/cluster_config'

describe 'cluster config' do
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

  # Mock shellrunner
  let(:status) { double(:status, success?: true) }

  it 'gets the kube namespace' do
    kubectl_output = ''
    KubeDeployTools::Shellrunner.shellrunner = instance_double("shellrunner", :check_call => [kubectl_output, nil, status])
    actual = KubeDeployTools.kube_namespace(context: 'fake-context')
    expected = 'default'
    expect(actual).to eq(expected)

    kubectl_output = 'some-other-namespace'
    KubeDeployTools::Shellrunner.shellrunner = instance_double("shellrunner", :check_call => [kubectl_output, nil, status])
    actual = KubeDeployTools.kube_namespace(context: 'fake-context')
    expected = kubectl_output
    expect(actual).to eq(expected)
  end
end

