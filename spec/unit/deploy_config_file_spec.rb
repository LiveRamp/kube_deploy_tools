require 'tempfile'

require 'kube_deploy_tools/deploy_config_file'

# File fixtures
DEPLOY_YAML = 'spec/resources/deploy.yaml'
DEPLOY_YML_V1 = 'spec/resources/deploy_v1.yml'
DEPLOY_YAML_V1_AS_V2 = 'spec/resources/deploy_v1_as_v2.yaml'

describe KubeDeployTools::DeployConfigFile do
  let(:logger) { KubeDeployTools::FormattedLogger.build() }

  before(:example) do
    KubeDeployTools::Logger.logger = logger
  end

  context 'primary fixture' do
    let(:config) { KubeDeployTools::DeployConfigFile.new(DEPLOY_YAML) }

    it 'contains information about default flags' do
      expect(config.default_flags).to eq({'baz' => 'bing', 'food' => 'bar', 'pull_policy' => 'IfNotPresent'})
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

    it 'contains information about artifacts' do
      expect(config.artifacts).to include(include('name' => 'local'))
      expect(config.artifacts).to include(include('name' => 'colo-service-prod'))
      expect(config.artifacts).to include(include('name' => 'us-east-1-prod'))
    end

    it 'outputs the same yaml when trying to upgrade to the current version' do
      # Convert fixture to yaml, then re-read it
      Tempfile.open("deploy.yaml from fixture") do |t|
        fixture = File.open(DEPLOY_YAML) { |f| f.read() }
        t << fixture
        t.close

        # Test fixing a v2 yaml: it should do nothing
        before = KubeDeployTools::DeployConfigFile.new(t.path)
        before.upgrade!

        # Re-read fixed v1-as-v2 yaml
        after = KubeDeployTools::DeployConfigFile.new(t.path)

        actual = after
        expected = config

        expect(actual.artifacts).to eq(expected.artifacts)
        expect(actual.flavors).to eq(expected.flavors)
        expect(actual.hooks).to match_array(expected.hooks)
      end
    end
  end

  describe 'KDT 1.x compatibility' do
    it 'reads a KDT 1.x deploy.yml' do
      actual = KubeDeployTools::DeployConfigFile.new(DEPLOY_YML_V1)
      expected = KubeDeployTools::DeployConfigFile.new(DEPLOY_YAML_V1_AS_V2)

      expect(actual.artifacts).to eq(expected.artifacts)
      expect(actual.flavors).to eq(expected.flavors)
      expect(actual.hooks).to match_array(expected.hooks)
    end

    it 'upgrades a KDT 1.x deploy.yml' do
      # Convert fixture to yaml, then re-read it
      Tempfile.open("deploy.yml from fixture") do |t|
        fixture = File.open(DEPLOY_YML_V1) { |f| f.read() }
        t << fixture
        t.close

        # Test fixing a v1 yaml to a v2 yaml
        before = KubeDeployTools::DeployConfigFile.new(t.path)
        before.upgrade!

        # Re-read fixed v1-as-v2 yaml
        after = KubeDeployTools::DeployConfigFile.new(t.path)

        actual = after
        expected = KubeDeployTools::DeployConfigFile.new(DEPLOY_YAML_V1_AS_V2)

        expect(actual.artifacts).to eq(expected.artifacts)
        expect(actual.flavors).to eq(expected.flavors)
        expect(actual.hooks).to match_array(expected.hooks)
      end
    end
  end
end
