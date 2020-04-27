require 'tempfile'

require 'kube_deploy_tools/generate'

INPUT_DIR='spec/resources/kubernetes/render-deploys-example/'
MANIFEST_FILE="spec/resources/deploy.yaml"
MANIFEST_FILE_NUM_CLUSTERS=9
JOB_NAME="FAKE_PROJECT"
BUILD_ID="12345"
GIT_COMMIT='123456789deadbeef123456789deadbeef'
GIT_PROJECT='git@git.***REMOVED***:MasterRepos/kube_deploy_tools_spec_test.git'

describe KubeDeployTools::Generate do
  let(:logger) { KubeDeployTools::FormattedLogger.build }
  let(:shellrunner) { instance_double("shellrunner", :check_call => nil) }
  let(:config) { KubeDeployTools::DeployConfigFile.new(MANIFEST_FILE) }
  let(:artifact_registry) { config.artifact_registries[config.artifact_registry] }

  before(:example) do
    KubeDeployTools::Logger.logger = logger
    KubeDeployTools::Shellrunner.shellrunner = shellrunner

    # NOTE(jmodes): rspec mocks do not support child processes
    # https://github.com/rspec/rspec-mocks/issues/59
    # https://stackoverflow.com/a/6159391/1881379
    allow_any_instance_of(Object).to receive(:fork) do |&block|
      block.call
    end

    allow(shellrunner).to receive(:check_call).with(*%w(git rev-parse HEAD)) do
      GIT_COMMIT
    end

    allow(shellrunner).to receive(:check_call).with(*%w(git config --get remote.origin.url)) do
      GIT_PROJECT
    end
  end

  it 'renders correct image_registry in kubernetes yaml' do
    Dir.mktmpdir do |tmp_dir|
      app = KubeDeployTools::Generate.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir,
        artifact_registry: artifact_registry,
      )
      app.generate
      expected = Dir["#{tmp_dir}/**/other.yaml"]
      expected.select{ |f| f =~ /local/ }.each do |rendered|
        expect(File.read(rendered)).to include("local-registry")
      end
    end
  end

  it 'can render multiple YAML documents in a single file' do
    manifest = Tempfile.new("deploy.yaml")
    manifest.write <<-YAML
version: 2
default_flags:
  pull_policy: IfNotPresent
artifacts:
  - name: local
    image_registry: local
    flags:
      target: local
      environment: staging
      cloud: local
flavors:
  default: {}
image_registries:
  - name: local
    driver: noop
    prefix: local-registry
  - name: gcp
    driver: gcp
    prefix: ***REMOVED***
YAML
    manifest.close
    input_dir = Dir.mktmpdir
    template = Tempfile.new(["statefulset-nginx", ".yaml.erb"], input_dir)
    template.write <<-YAML
<%- num_pods_per_node=3 -%>
<%- num_pods_per_node.times do |x| -%>
---
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  namespace: default
  name: test-nginx-<%= x %>
spec: {}
<%- end -%>
---
# empty
---
YAML

    template.close
    tmp_dir = Dir.mktmpdir
    begin
      app = KubeDeployTools::Generate.new(
        manifest,
        input_dir,
        tmp_dir,
        artifact_registry: artifact_registry,
      )
      app.generate
      expected = Dir["#{tmp_dir}/**/statefulset-nginx*.yaml"]
      expect(expected.length).to eq(1)
      expected.each do |rendered|
        expect(File.read(rendered)).to include("test-nginx-0")
        expect(File.read(rendered)).to include("test-nginx-1")
        expect(File.read(rendered)).to include("test-nginx-2")
        expect(YAML.load_stream(File.read(rendered)).length).to eq(3)
        expect(File.read(rendered)).not_to include("empty")
      end
    ensure
      FileUtils.remove_entry input_dir
      FileUtils.remove_entry tmp_dir
      manifest.close
      manifest.unlink
    end
  end

  it "renders deploys for all clusters" do
    Dir.mktmpdir do |tmp_dir|
      # Stub out ENV
      ENV["JOB_NAME"] = JOB_NAME
      ENV["BUILD_ID"] = BUILD_ID

      app = KubeDeployTools::Generate.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir,
        artifact_registry: artifact_registry,
      )

      app.generate

      expectation = <<-YAML
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  namespace: default
  name: test-nginx
  labels:
    from_default_flag: bing
    tag: REMOVED
  annotations:
    git_commit: #{GIT_COMMIT}
    git_project: #{GIT_PROJECT}
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

      clusters = %w(local pippio-production platforms-prod ingestion-prod us-east-1-prod us-east-1-staging colo-service-prod colo-service-staging)
      expected = clusters.map do |cluster|
        File.join(tmp_dir, "#{cluster}_default", 'nginx', 'dep-nginx.yaml')
      end +
      clusters.map do |cluster|
        File.join(tmp_dir, "#{cluster}_default", 'other', 'other.yaml')
      end +
      [ File.join(tmp_dir, "filtered-artifact_default", 'nginx', 'dep-nginx.yaml') ]

      expect(Dir["#{tmp_dir}/**/*.yaml"]).to contain_exactly(*expected)
      expected.select{ |f| f =~ /nginx/ }.each do |rendered|
        rendered_no_tag = File.read(rendered).gsub(/tag: .*/, 'tag: REMOVED')
        expect(rendered_no_tag).to eq(expectation)
      end
      expect(shellrunner).to have_received(:check_call).with('tar', any_args).exactly(MANIFEST_FILE_NUM_CLUSTERS).times
    end
  end

  it "doesn't render deploys for any clusters on print only" do
    Dir.mktmpdir do |tmp_dir|
      # Stub out ENV
      ENV["JOB_NAME"] = JOB_NAME
      ENV["BUILD_ID"] = BUILD_ID

      app = KubeDeployTools::Generate.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir,
        print_flags_only: true,
        artifact_registry: artifact_registry,
      )

      app.generate

      expect(Dir["#{tmp_dir}/*"].empty?).to be true
    end
  end

  it "can set ERB context values from literals" do
    Dir.mktmpdir do |tmp_dir|
      expected_value = "my_image_tag"
      app = KubeDeployTools::Generate.new(
        MANIFEST_FILE,
        INPUT_DIR,
        tmp_dir,
        literals: {'image_tag' => expected_value},
        artifact_registry: artifact_registry,
      )
      app.generate
      expected = Dir["#{tmp_dir}/**/other.yaml"]
      expected.each do |rendered|
        expect(File.read(rendered)).to include("kube_deploy_tools:#{expected_value}")
      end
    end
  end
end
