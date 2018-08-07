require 'kube_deploy_tools/deploy_config_file'

MANIFEST_FILE = 'spec/resources/deploy.yml'

describe KubeDeployTools::DeployConfigFile do
  context 'primary fixture' do
    let(:config) { KubeDeployTools::DeployConfigFile.new(MANIFEST_FILE) }

    it 'contains information about default flags' do
      expect(config.default_flags).to eq({'baz' => 'bing', 'food' => 'bar'})
    end

    it 'contains correct information about image registries' do
      aws = config.image_registries.fetch('aws')
      expect(aws.prefix).to eq('123456789.dkr.ecr.us-west-2.amazonaws.com')
      expect(aws.config.fetch('region')).to eq('us-west-2')
      expect(aws.driver).to eq('aws')

      gcp = config.image_registries.fetch('gcp')
      expect(gcp.prefix).to eq('gcr.io/kdt-example')
      expect(gcp.driver).to eq('gcp')

      local = config.image_registries.fetch('local')
      expect(local.prefix).to eq('local-registry')
      expect(local.driver).to eq('noop')

      artifactory = config.image_registries.fetch('artifactory')
      expect(artifactory.prefix).to eq('my-artifactory.com:1234')
      expect(artifactory.driver).to eq('login')
      expect(artifactory.config).to eq({'username_var' => 'ARTIFACTORY_USERNAME', 'password_var' => 'ARTIFACTORY_PASSWORD'})
    end
  end

  context 'busted fixture' do
    it 'dies when default_flags is not a hash' do
      expect do
        KubeDeployTools::DeployConfigFile.new('spec/resources/bad_default_flags.yaml')
      end.to raise_error('default_flags is not a Hash')
    end
  end
end
