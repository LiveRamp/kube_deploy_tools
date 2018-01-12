require 'fileutils'
require 'tmpdir'

require 'kube_deploy_tools/deploy_artifact'
require 'kube_deploy_tools/formatted_logger'

LOCAL_ARTIFACT='manifests_local_staging_default'
LOCAL_COMPRESSED_ARTIFACT="#{LOCAL_ARTIFACT}.tar.gz"
REMOTE_ARTIFACT="http://***REMOVED***/artifactory/kubernetes-snapshot-local/FAKEPROJECT/FAKEJOBNUMBER/#{LOCAL_COMPRESSED_ARTIFACT}"
TEST_RESOURCES='spec/resources/'
KUBE_RESOURCE_NEW = 'new.yaml'


describe KubeDeployTools::DeployArtifact do
  let(:logger) { KubeDeployTools::FormattedLogger.build }

  # Mock shellrunner
  let(:status) { double(:status, success?: true) }
  let(:stdoutput) { 'fake stdoutput' }
  let(:shellrunner) { instance_double("shellrunner", :run_call => [stdoutput, nil, status]) }

  it "downloads and uncompresses a remote, compressed deploy artifact" do
    Dir.mktmpdir do |tmp_dir|
      deploy_artifact = KubeDeployTools::DeployArtifact.new(
        logger: logger,
        shellrunner: shellrunner,
        input_path: REMOTE_ARTIFACT,
        output_dir_path: tmp_dir,
      )

      local_compressed_artifact = File.join(tmp_dir, LOCAL_COMPRESSED_ARTIFACT)
      local_artifact = File.join(tmp_dir, LOCAL_ARTIFACT)

      # stub out `curl` and `tar -x`
      allow(shellrunner).to receive(:run_call).with('curl', any_args) {
        # Simulate artifact download with tarball copy
        FileUtils.cp(
          File.join(TEST_RESOURCES, LOCAL_COMPRESSED_ARTIFACT),
          local_compressed_artifact,
        )
        [stdoutput, nil, status]
      }

      allow(shellrunner).to receive(:run_call).with('tar', any_args) {
        # Simulate uncompressing tarball with making the directory
        FileUtils.touch("#{local_artifact}/KUBE_RESOURCE_NEW")
        [stdoutput, nil, status]
      }

      path = deploy_artifact.path

      expect(Dir["#{tmp_dir}/*"]).to include(local_compressed_artifact)
      expect(File.directory?(local_artifact)).to be true
      expect(path).to eq(local_artifact)
    end
  end
end
