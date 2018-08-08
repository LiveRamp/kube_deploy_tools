require 'kube_deploy_tools/render_deploys'

INPUT_DIR='spec/resources/kubernetes/render-deploys-example/'
MANIFEST_FILE="spec/resources/deploy.yml"
MANIFEST_FILE_NUM_CLUSTERS=8
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
    from_default_flag: bing
    tag: REMOVED
spec:
  replicas: 0
  template:
    spec:
      containers:
      - name: nginx
        image: nginx
        imagePullPolicy: IfNotPresent
        ports:
        - name: web
          containerPort: 80

YAML

      clusters = %w(local_staging pippio-production_prod platforms_prod ingestion_prod us-east-1_prod us-east-1_staging colo-service_prod colo-service_staging)
      expected = clusters.map do |cluster|
        File.join(tmp_dir, "#{cluster}_default", 'dep-nginx.yaml')
      end
      expect(Dir["#{tmp_dir}/**/*.yaml"]).to contain_exactly(*expected)
      expected.each do |rendered|
        rendered_no_tag = File.read(rendered).gsub(/tag: .*/, 'tag: REMOVED')
        expect(rendered_no_tag).to eq(expectation)
      end
      expect(shellrunner).to have_received(:check_call).with('tar', any_args).exactly(MANIFEST_FILE_NUM_CLUSTERS).times
    end
  end
end

