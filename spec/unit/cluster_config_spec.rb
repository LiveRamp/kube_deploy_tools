require 'kube_deploy_tools/cluster_config'

describe 'cluster config' do
  it "creates a valid Docker tag" do
    tag = KubeDeployTools.tag_from_local_env
    expect(tag).to match(/[\w][\w.-]{0,127}/)
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

