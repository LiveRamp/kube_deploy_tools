require 'set'

require 'kube_deploy_tools/publish_artifacts'

MANIFEST_FILE='spec/resources/deploy.yml'
OUTPUT_DIR='fake/kubernetes/'
PROJECT='my-project'

describe KubeDeployTools::PublishArtifacts do
  let(:logger) { KubeDeployTools::FormattedLogger.build }

  it 'publishes artifacts according to deploy.yml' do
    KubeDeployTools::Logger.logger = logger
    KubeDeployTools::PROJECT = PROJECT

    # Stub out artifacts
    allow(File).to receive(:exist?).and_return(true)

    # Stub out YAML load
    allow(YAML).to receive(:load_file).and_return({})

    # Mock artifact upload
    uploads = Set.new
    allow_any_instance_of(Artifactory::Resource::Artifact).to receive(:upload) do |artifact, repo, path|
      # Expect to upload to kubernetes-snapshots-local/<project>
      expect(repo).to eq(KubeDeployTools::ARTIFACTORY_REPO)
      expect(path).to start_with(PROJECT)

      # add only the basenames of the files to the set as the BUILD_ID
      # will vary on each build
      uploads.add(File.basename(path))
    end

    KubeDeployTools::PublishArtifacts.new(
      # This extra file happens to be a yml file, but any existent file
      # can be put here. This is just convenient so we don't need to
      # create an extra data fixture in the repo.
      extra_files: [MANIFEST_FILE],
      manifest: MANIFEST_FILE,
      output_dir: OUTPUT_DIR,
    ).publish

    # images.yaml, tarballs, and bare deploy.yml to test extra file
    # support
    expected_uploads = [
      'manifests_colo-service-prod_default.tar.gz',
      'manifests_colo-service-staging_default.tar.gz',
      'manifests_local_default.tar.gz',
      'manifests_us-east-1-prod_default.tar.gz',
      'manifests_us-east-1-staging_default.tar.gz',
      'manifests_ingestion-prod_default.tar.gz',
      'manifests_pippio-production_default.tar.gz',
      'manifests_platforms-prod_default.tar.gz',
      'deploy.yml',
      'images.yaml',
    ]
    expect(uploads).to contain_exactly(*expected_uploads)
  end
end

