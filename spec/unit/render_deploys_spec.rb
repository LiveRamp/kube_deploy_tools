require 'kube_deploy_tools/render_deploys'

INPUT_DIR='spec/resources/kubernetes/render-deploys-example/'
MANIFEST_FILE="spec/resources/deploy.yml"
MANIFEST_FILE_NUM_CLUSTERS=6
JOB_NAME="FAKE_PROJECT"
BUILD_ID="12345"

describe KubeDeployTools::RenderDeploys do
  let(:shellrunner) { instance_double("shellrunner", :check_call => nil) }

  before(:example) do
    KubeDeployTools::Shellrunner.shellrunner = shellrunner
  end

  it "renders deploys for all clusters" do
    Dir.mktmpdir do |tmp_dir|
      # Stub out ENV
      ENV["JOB_NAME"] = JOB_NAME
      ENV["BUILD_ID"] = BUILD_ID

      app = KubeDeployTools::RenderDeploys.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir
      )

      # NOTE(jmodes): rspec mocks do not support child processes
      # https://github.com/rspec/rspec-mocks/issues/59
      # https://stackoverflow.com/a/6159391/1881379
      allow(app).to receive(:fork) do |&block|
        block.call
      end

      app.render

      expectation = <<-YAML

apiVersion: apps/v1beta1
kind: Deployment
metadata:
  namespace: default
  name: test-nginx
  labels:
    tag: REMOVED
spec:
  replicas: 0
  template:
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - name: web
          containerPort: 80

YAML

      flavors = %w(local/staging gcp/prod us-east-1/prod us-east-1/staging colo-service/prod colo-service/staging)
      flavors.each do |flavor|
        rendered = File.join(tmp_dir, flavor, 'default', 'dep-nginx.yaml')
        expect(File.file?(rendered)).to be(true)
        rendered_no_tag = File.read(rendered).gsub(/tag: .*/, 'tag: REMOVED')
        expect(rendered_no_tag).to eq(expectation)
      end
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
        tmp_dir
      )

      app.render

      expect(File.file?(File.join(tmp_dir, 'artifactory.json'))).to be(true)
    end
  end
end

