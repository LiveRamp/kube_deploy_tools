require 'fileutils'
require 'tmpdir'

require 'kube_deploy_tools/deploy_artifact'

LOCAL_ARTIFACT='manifests_local_staging_default'
LOCAL_COMPRESSED_ARTIFACT="#{LOCAL_ARTIFACT}.tar.gz"
REMOTE_ARTIFACT="http://***REMOVED***/artifactory/kubernetes-snapshot-local/FAKEPROJECT/FAKEJOBNUMBER/#{LOCAL_COMPRESSED_ARTIFACT}"
TEST_RESOURCES='spec/resources/'
KUBE_RESOURCE_NEW = 'new.yaml'


describe KubeDeployTools::DeployArtifact do
  before(:example) do
    KubeDeployTools::Shellrunner.shellrunner = shellrunner
  end

  # Mock shellrunner
  let(:status) { double(:status, success?: true) }
  let(:stdoutput) { 'fake stdoutput' }
  let(:shellrunner) { instance_double("shellrunner", :run_call => [stdoutput, nil, status]) }

  context 'when build is latest' do
    fake_html = '<a href="13/">13/</a>    08-Dec-2017 13:10    -
                <a href="14/">14/</a>    08-Dec-2017 13:11    -
                <a href="15/">15/</a>    11-Dec-2017 14:21    -
                <a href="18/">18/</a>    14-Dec-2017 14:57    -
                <a href="19/">19/</a>    19-Dec-2017 12:37    -'

    it "retrieves latest build number" do
      latest_build_number = '19'

      # stub out `curl`
      allow(shellrunner).to receive(:run_call).with('curl', any_args) {
        # Simulate html curling
        [fake_html, nil, status]
      }
      
      remote_url = KubeDeployTools.get_remote_deploy_artifact_url(
        project: "foo",
        build_number: "latest",
        target: "targetX",
        environment: "prod",
        flavor: "",
      )

      expect(remote_url).to include(latest_build_number)
    end
  end

  it "downloads and uncompresses a remote, compressed deploy artifact" do

    Dir.mktmpdir do |tmp_dir|
      deploy_artifact = KubeDeployTools::DeployArtifact.new(
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
