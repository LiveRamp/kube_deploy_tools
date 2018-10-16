require 'tempfile'

require 'kube_deploy_tools/sweeper'

SWEEPER_CONFIG='spec/resources/sweeper.yml'

describe KubeDeployTools::Sweeper do
  # Use a test spy for Logger
  let(:logger) { instance_double('logger', :error => {}) }

  before(:example) do
    # Wire up test spy
    KubeDeployTools::Logger.logger = logger

    ENV['ARTIFACTORY_USERNAME'] = 'fake-user'
    ENV['ARTIFACTORY_PASSWORD'] = 'fake-password'
    ENV['ARTIFACTORY_HOST'] = 'fake-host'
  end

  # Test config file and flag configuration for a new sweeper
  describe('sweeper configuration') do

    it 'errors without a config file' do
      config_file_path = 'non-existent-deploy.yml'
      artifactory_repo = 'kubernetes-snapshot-local'
      artifactory_pattern = nil
      retention = '14d'
      dryrun = true

      expect do
        sweeper = KubeDeployTools::Sweeper.new(
          config_file_path,
          artifactory_repo,
          artifactory_pattern,
          retention,
          dryrun)
      end.to raise_error(/Could not locate file/)
    end

    it 'accepts a config file' do
      config_file_path = SWEEPER_CONFIG
      dryrun = true
      sweeper = KubeDeployTools::Sweeper.new(
        config_file_path,
        nil,
        nil,
        nil,
        dryrun)

      expected_configs = [
        {
          'repository' => 'kubernetes-snapshot-local',
          'prefixes' => [
            { 'pattern' => 'fake_prefix', 'retention' => '1d' }
          ],
        }
      ]
      expect(sweeper.instance_variable_get(:@sweeper_configs)).to eql(expected_configs)
      expect(logger).not_to have_received(:error).with(/This config file does not exist/)
    end

    it 'accepts config flags' do
      config_file_path = SWEEPER_CONFIG
      artifactory_repo = 'kubernetes-snapshot-local'
      artifactory_pattern = 'fake/path/to/artifactory'
      retention = '14d'
      dryrun = true
      sweeper = KubeDeployTools::Sweeper.new(
        config_file_path,
        artifactory_repo,
        artifactory_pattern,
        retention,
        dryrun)

      expected_configs = [
        {
          'repository' => artifactory_repo,
          'prefixes' => [
            { 'pattern' => artifactory_pattern, 'retention' => retention }
          ],
        }
      ]
      expect(sweeper.instance_variable_get(:@sweeper_configs)).to eql(expected_configs)
      expect(logger).not_to have_received(:error).with(/This config file does not exist/)
    end
  end
end
