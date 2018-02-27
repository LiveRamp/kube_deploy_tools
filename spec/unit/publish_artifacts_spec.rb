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

    # Mock artifact upload
    allow_any_instance_of(Artifactory::Resource::Artifact).to receive(:upload) do |artifact, repo, path|
      # Expect to upload to kubernetes-snapshots-local/<project>
      expect(repo).to eq(KubeDeployTools::ARTIFACTORY_REPO)
      expect(path).to start_with(PROJECT)
      expect(path).to end_with('.tar.gz').or end_with('images.yaml')
    end

    KubeDeployTools::PublishArtifacts.new(
      manifest: MANIFEST_FILE,
      output_dir: OUTPUT_DIR,
    ).publish
  end
end

