require 'set'
require 'fileutils'

require 'kube_deploy_tools/publish'

MANIFEST_FILE='spec/resources/deploy.yaml'
MANIFEST_GCS_FILE='spec/resources/deploy_gcs.yaml'
PROJECT='my-project'
INPUT_DIR='spec/resources/publish/kubernetes/.'

describe KubeDeployTools::Publish do
  let(:logger) { KubeDeployTools::FormattedLogger.build }
  let(:config) { KubeDeployTools::DeployConfigFile.new(MANIFEST_FILE) }
  let(:shellrunner) { instance_double("publish_shellrunner", :check_call => nil) }

  before(:example) do
    KubeDeployTools::PROJECT = PROJECT
    KubeDeployTools::Shellrunner.shellrunner = shellrunner
    allow(shellrunner).to receive(:check_call).with('tar', any_args)
    allow(shellrunner).to receive(:run_call).with('gsutil', any_args) do
      ['stdout', '', double("status", success?: true)]
    end
  end

  let(:artifact_registry) {
    fake_artifact_registry_driver = double("artifact_registry_driver")
    allow(fake_artifact_registry_driver).to receive(:generate)

    fake_artifact_registry = double("artifact_registry")
    expect(fake_artifact_registry).to receive(:driver).and_return(fake_artifact_registry_driver)

    fake_artifact_registry
  }

  context 'Artifactory driver' do
    let(:artifact_registry) { config.artifact_registries[config.artifact_registry] }

    it 'publishes artifacts according to deploy.yaml' do

      KubeDeployTools::Logger.logger = logger

      # Mock artifact upload
      uploads = Set.new
      allow_any_instance_of(Artifactory::Resource::Artifact).to receive(:upload) do |artifact, repo, path|
        # Expect to upload to kubernetes-snapshots-local/<project>
        expect(path).to start_with(PROJECT)

        # add only the basenames of the files to the set as the BUILD_ID
        # will vary on each build
        uploads.add(File.basename(path))
      end

      expected_uploads = [
        'manifests_colo-service-prod_default.tar.gz',
        'manifests_colo-service-staging_default.tar.gz',
        'manifests_local_default.tar.gz',
        'manifests_us-east-1-prod_default.tar.gz',
        'manifests_us-east-1-staging_default.tar.gz',
        'manifests_ingestion-prod_default.tar.gz',
        'manifests_pippio-production_default.tar.gz',
        'manifests_platforms-prod_default.tar.gz',
        'manifests_filtered-artifact_default.tar.gz',
      ]


      Dir.mktmpdir do |dir|

        expected_uploads.each do |f|

          FileUtils.touch File.join(dir, f)
        end

        KubeDeployTools::Publish.new(
          manifest: MANIFEST_FILE,
          artifact_registry: artifact_registry,
          output_dir: dir,
        ).publish
      end

      all_uploads = expected_uploads
      expect(uploads).to contain_exactly(*all_uploads)
    end

    it 'publishes artifacts according to deploy.yaml and given env & app name' do

      KubeDeployTools::Logger.logger = logger

      # Mock artifact upload
      uploads = Set.new
      allow_any_instance_of(Artifactory::Resource::Artifact).to receive(:upload) do |artifact, repo, path|
        # Expect to upload to kubernetes-snapshots-local/<project>
        expect(path).to start_with(PROJECT)

        # add only the basenames of the files to the set as the BUILD_ID
        # will vary on each build
        uploads.add(File.basename(path))
      end

      expected_uploads = [
        'manifests_colo-service-prod_default.tar.gz',
        'manifests_colo-service-staging_default.tar.gz',
        'manifests_local_default.tar.gz',
        'manifests_us-east-1-prod_default.tar.gz',
        'manifests_us-east-1-staging_default.tar.gz',
        'manifests_ingestion-prod_default.tar.gz',
        'manifests_pippio-production_default.tar.gz',
        'manifests_platforms-prod_default.tar.gz',
        'manifests_filtered-artifact_default.tar.gz',
      ]


      Dir.mktmpdir do |dir|

        expected_uploads.each do |f|

          FileUtils.touch File.join(dir, f)
        end

        KubeDeployTools::Publish.new(
          manifest: MANIFEST_FILE,
          artifact_registry: artifact_registry,
          output_dir: dir,
        ).publish_with_env_app("env", "app")
      end

      all_uploads = expected_uploads
      expect(uploads).to contain_exactly(*all_uploads)
    end
  end

  context 'GCS driver' do
    let(:artifact_registry) { config.artifact_registries['gcs'] }

    it 'publishes artifacts according to deploy.yaml' do
      KubeDeployTools::Logger.logger = logger

      Dir.tmpdir do |dir|
        FileUtils.cp_r INPUT_DIR, dir, :verbose => true
        KubeDeployTools::Publish.new(
          manifest: MANIFEST_GCS_FILE,
          artifact_registry: artifact_registry,
          output_dir: dir,
        ).publish

        artifacts = Find.find(dir).
          select { |path| path =~ /.*manifests_.*\.yaml$/ }

        expect(artifacts.length).to eq(1)

        # Check that the local artifact contains 2 concatenated resources
        local_artifact = artifacts.select { |path| path =~ /local/ }.first
        local_artifact_contents = YAML.load_file(local_artifact)
        local_artifact_resources = []
        YAML.load_stream(File.read local_artifact) { |doc| local_artifact_resources << doc }
        expect(local_artifact_resources.length).to eq(2)
      end
    end

    it 'publishes artifacts according to deploy.yaml and given env & app name' do
      KubeDeployTools::Logger.logger = logger

      Dir.tmpdir do |dir|
        FileUtils.cp_r INPUT_DIR, dir, :verbose => true
        KubeDeployTools::Publish.new(
          manifest: MANIFEST_GCS_FILE,
          artifact_registry: artifact_registry,
          output_dir: dir,
        ).publish_with_env_app("env", "app")

        artifacts = Find.find(dir).
          select { |path| path =~ /.*manifests_.*\.yaml$/ }

        expect(artifacts.length).to eq(1)

        # Check that the local artifact contains 2 concatenated resources
        local_artifact = artifacts.select { |path| path =~ /local/ }.first
        local_artifact_contents = YAML.load_file(local_artifact)
        local_artifact_resources = []
        YAML.load_stream(File.read local_artifact) { |doc| local_artifact_resources << doc }
        expect(local_artifact_resources.length).to eq(2)
      end
    end
  end
end

