require 'kube_deploy_tools/render_deploys'

INPUT_DIR='spec/resources/kubernetes/render-deploys-example/'
MANIFEST_FILE="spec/resources/deploy.yml"
MANIFEST_FILE_NUM_CLUSTERS=6
JOB_NAME="FAKE_PROJECT"
BUILD_ID="12345"

describe KubeDeployTools::RenderDeploys do
  let(:shellrunner) { instance_double("shellrunner", :check_call => nil) }

  it "renders deploys for all clusters" do
    Dir.mktmpdir do |tmp_dir|
      # Stub out ENV
      ENV["JOB_NAME"] = JOB_NAME
      ENV["BUILD_ID"] = BUILD_ID

      app = KubeDeployTools::RenderDeploys.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir,
        shellrunner: shellrunner,
      )

      # NOTE(jmodes): rspec mocks do not support child processes
      # https://github.com/rspec/rspec-mocks/issues/59
      # https://stackoverflow.com/a/6159391/1881379
      allow(app).to receive(:fork) do |&block|
        block.call
      end

      app.render

      expect(shellrunner).to have_received(:check_call).with('bundle', 'exec', any_args).exactly(MANIFEST_FILE_NUM_CLUSTERS).times
      expect(shellrunner).to have_received(:check_call).with('tar', any_args).exactly(MANIFEST_FILE_NUM_CLUSTERS).times

      expect(File.file?(File.join(tmp_dir, 'artifactory.json'))).to be(true)
    end
  end

  it "adds artifactory.json" do
    Dir.mktmpdir do |tmp_dir|
      # Stub out ENV
      ENV["JOB_NAME"] = JOB_NAME
      ENV["BUILD_ID"] = BUILD_ID

      app = KubeDeployTools::RenderDeploys.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir,
        shellrunner: shellrunner,
      )

      app.render

      expect(File.file?(File.join(tmp_dir, 'artifactory.json'))).to be(true)
    end
  end
end

