require 'tmpdir'
require 'kube_deploy_tools/make_configmap'
require 'kube_deploy_tools/make_configmap/options'


CONFIGMAP_DATA_FILE_NAME="haproxy.cfg"
CONFIGMAP_DATA_DIRECTORY_PATH="spec/resources/config/"
CONFIGMAP_DATA_FILE_PATH=File.join(CONFIGMAP_DATA_DIRECTORY_PATH, CONFIGMAP_DATA_FILE_NAME)
CONFIGMAP_DATA_FILE_CONTENT=File.read(CONFIGMAP_DATA_FILE_PATH)

CONFIGMAP_NAME="my-haproxy-config"
CONFIGMAP_DEFAULT_NAMESPACE="default"
CONFIGMAP_FILE_PATH="spec/resources/kubernetes/configmap/configmap-haproxy.yaml"
CONFIGMAP_FILE_CONTENT=File.read(CONFIGMAP_FILE_PATH)

describe KubeDeployTools::ConfigMap do
  context 'when --from-file is a file' do

    let(:configmap_from_file) { [CONFIGMAP_DATA_FILE_PATH] }

    it 'writes a ConfigMap' do
      configmap = KubeDeployTools::ConfigMap.new(CONFIGMAP_NAME, configmap_from_file).target_hash
      configmap_content = YAML::dump(configmap)

      expect(configmap_content).to start_with(CONFIGMAP_FILE_CONTENT)
      expect(configmap['metadata']['name']).to eq(CONFIGMAP_NAME)
      expect(configmap['metadata']['namespace']).to eq(CONFIGMAP_DEFAULT_NAMESPACE)
      expect(configmap['metadata']['labels']).to be_nil
      expect(configmap['data'][CONFIGMAP_DATA_FILE_NAME]).to eq(CONFIGMAP_DATA_FILE_CONTENT)
    end

    it 'writes a ConfigMap with .metadata.namespace and .metadata.labels' do
      namespace = 'my-namespace'
      label_name = 'app'
      label_value = 'frontend'
      labels = { label_name => label_value }

      configmap = KubeDeployTools::ConfigMap.new(CONFIGMAP_NAME, configmap_from_file, namespace, labels).target_hash
      configmap_content = YAML::dump(configmap)

      expect(configmap['metadata']['name']).to eq(CONFIGMAP_NAME)
      expect(configmap['metadata']['namespace']).to eq(namespace)
      expect(configmap['metadata']['labels'][label_name]).to eq(label_value)
      expect(configmap['data'][CONFIGMAP_DATA_FILE_NAME]).to eq(CONFIGMAP_DATA_FILE_CONTENT)
    end
  end

  context 'when --from-file is a directory' do

    let(:configmap_from_file) { [CONFIGMAP_DATA_DIRECTORY_PATH] }

    it 'writes a ConfigMap' do
      configmap = KubeDeployTools::ConfigMap.new(CONFIGMAP_NAME, configmap_from_file).target_hash
      configmap_content = YAML::dump(configmap)

      expect(configmap_content).to start_with(CONFIGMAP_FILE_CONTENT)
      expect(configmap['metadata']['name']).to eq(CONFIGMAP_NAME)
      expect(configmap['metadata']['namespace']).to eq(CONFIGMAP_DEFAULT_NAMESPACE)
      expect(configmap['data'][CONFIGMAP_DATA_FILE_NAME]).to eq(CONFIGMAP_DATA_FILE_CONTENT)
    end
  end

  context 'when --from-file is key=filepath' do

    let(:configmap_from_file) { ["#{CONFIGMAP_DATA_FILE_NAME}=#{CONFIGMAP_DATA_FILE_PATH}"] }

    it 'writes a ConfigMap' do
      configmap = KubeDeployTools::ConfigMap.new(CONFIGMAP_NAME, configmap_from_file).target_hash
      configmap_content = YAML::dump(configmap)

      expect(configmap_content).to start_with(CONFIGMAP_FILE_CONTENT)
      expect(configmap['metadata']['name']).to eq(CONFIGMAP_NAME)
      expect(configmap['metadata']['namespace']).to eq(CONFIGMAP_DEFAULT_NAMESPACE)
      expect(configmap['data'][CONFIGMAP_DATA_FILE_NAME]).to eq(CONFIGMAP_DATA_FILE_CONTENT)
    end
  end
end
