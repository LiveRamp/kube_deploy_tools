require 'kube_deploy_tools/tag'

describe 'cluster config' do
  it "creates a valid Docker tag" do
    tag = KubeDeployTools.tag_from_local_env
    expect(tag).to match(/[\w][\w.-]{0,127}/)
  end
  it 'includes BUILD_ID' do
    ENV.delete('BUILD_ID')
    ENV['BUILD_ID'] = '12345'
    tag = KubeDeployTools.tag_from_local_env
    expect(tag).to include(ENV['BUILD_ID'])

    ENV.delete('BUILD_ID')
    tag = KubeDeployTools.tag_from_local_env
    expect(tag).to include('dev')
  end
end

