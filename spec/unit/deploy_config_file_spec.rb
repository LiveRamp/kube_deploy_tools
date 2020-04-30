require 'tempfile'

require 'kube_deploy_tools/deploy_config_file'

# File fixtures
DEPLOY_YAML = 'spec/resources/deploy.yaml'
DEPLOY_YAML_MERGE_1 = 'spec/resources/merge_1.yaml'
DEPLOY_YAML_MERGE_2 = 'spec/resources/merge_2.yaml'
DEPLOY_YAML_MERGE_3 = 'spec/resources/merge_3.yaml'

describe KubeDeployTools::DeployConfigFile do
  let(:logger) { KubeDeployTools::FormattedLogger.build() }
  let(:expected_merge_three) do
    {
      "artifacts" => [{"name" => "gcp", "image_registry" => "gcp", "flags" => {"marco" => "polo", "and" => "that"}}],
      "default_flags" => {"hey" => "ho", "lo" => "last", "beatles" => "band"},
      "expiration" => [{"repository" => "https://***REMOVED***/artifactory", "prefixes"=>[{"pattern" => "asdf", "retention" => "30d"}]}],
      "flavors" => {"default" => {"one" => "two"}},
      "hooks" => ["run_me_first", "default"],
      "image_registries" => [{"name" => "gcp", "driver" => "gcp", "prefix" => "***REMOVED***3", "config" => nil}],
    }
  end

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
  end

  context 'deploy.yamls with library files' do
    let(:shellrunner) { instance_double("shellrunner") }

    before(:example) do
      KubeDeployTools::Shellrunner.shellrunner = shellrunner
    end

    it 'can reference local libraries from a deploy.yaml' do
      config = KubeDeployTools::DeployConfigFile.new('spec/resources/library_local.yaml')
      expect(config.to_h).to eq(expected_merge_three)
    end

    it 'can reference gcs based libraries from a deploy.yaml' do
      allow(shellrunner).to receive(:check_call).with('gsutil', 'cat', 'gs://my-kdt-libraries/merge_2.yaml').
        and_return(File.read(DEPLOY_YAML_MERGE_2))

      allow(shellrunner).to receive(:check_call).with('gsutil', 'cat', 'gs://my-kdt-libraries/merge_3.yaml').
        and_return(File.read(DEPLOY_YAML_MERGE_3))

      config = KubeDeployTools::DeployConfigFile.new('spec/resources/library_gcs.yaml')
      expect(config.to_h).to eq(expected_merge_three)
    end
  end

  context 'config extension' do
    let(:library) { KubeDeployTools::DeployConfigFile.new(DEPLOY_YAML_MERGE_1) }
    let(:parent) { KubeDeployTools::DeployConfigFile.new(DEPLOY_YAML_MERGE_2) }

    it 'can extend one config with another' do
      expected = {
        "artifacts" => [{"name" => "gcp", "image_registry" => "gcp", "flags" => {"marco" => "holo", "also" => "this"}}],
        "default_flags" => {"hey" => "yo", "lo" => "hi", "beatles" => "band"},
        "expiration" => [{"repository" => "https://***REMOVED***/artifactory", "prefixes"=>[{"pattern" => "asdf", "retention" => "30d"}]}],
        "flavors" => {"default" => {"one" => "two"}},
        "hooks" => ["default", "run_me_first"],
        "image_registries" => [{"name" => "gcp", "driver" => "gcp", "prefix" => "***REMOVED***2", "config" => nil}],
      }

      parent.extend!(library)
      expect(parent.to_h).to eq(expected)
    end
  end
end
