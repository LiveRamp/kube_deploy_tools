require 'tmpdir'
require 'kube_deploy_tools/make_configmap'
require 'kube_deploy_tools/make_configmap/options'

CONFIGMAP_FILENAME_TEMPLATE="haproxy.cfg.erb"
CONFIGMAP_CONTENT_FILE="haproxy.yaml"
CONFIGMAP_CONTENT="spec/resources/kubernetes/config/#{CONFIGMAP_CONTENT_FILE}"
CONFIGMAP_FILEPATH="spec/resources/kubernetes/config/#{CONFIGMAP_FILENAME_TEMPLATE}"

describe KubeDeployTools::ConfigMap do
  it "writes to output a string " do
    Dir.mktmpdir do |tmp_dir|
      make_configmap = KubeDeployTools::ConfigMap.new('test', 'default', [CONFIGMAP_FILEPATH])
      output = YAML::dump(make_configmap.target_hash)
      expect(File.read(CONFIGMAP_CONTENT)).to eq(output)
    end
  end
end
