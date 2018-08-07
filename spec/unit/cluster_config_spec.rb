require 'kube_deploy_tools/tag'

describe 'cluster config' do
  it "creates a valid Docker tag" do
    tag = KubeDeployTools.tag_from_local_env
    expect(tag).to match(/[\w][\w.-]{0,127}/)
  end
end

