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
end

