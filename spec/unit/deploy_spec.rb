require 'kube_deploy_tools/deploy'
require 'kube_deploy_tools/deploy/options'

KUBERNETES_MANIFESTS_INVALID_NGINX="spec/resources/kubernetes/invalid-nginx/"
KUBERNETES_MANIFESTS_TEST_NGINX="spec/resources/kubernetes/test-nginx/"
CONTEXT="fake.context.k8s"
def make_argv(ops)
  ops.flat_map do |k,v|
    ["--#{k}", v]
  end
end

def parse(ops)
  KubeDeployTools::Deploy::Optparser.new.parse(make_argv(ops))
end

target = 'bogus-target-cluster'
environment = 'staging'
build_number = '12345'

describe KubeDeployTools::Deploy do
  let(:logger) { KubeDeployTools::FormattedLogger.build(context: CONTEXT) }

  # Mock kubectl
  let(:status) { double(:status, success?: true) }
  let(:stdoutput) { 'kubectl bogus output' }
  let(:kubectl) { instance_double("kubectl", :run => [stdoutput, nil, status]) }

  # Mock out `kubectl ... -o json` calls in KubeDeployTools::Deployment < KubernetesResource
  before(:example) do
    allow_any_instance_of(KubeDeployTools::Deployment).to receive(:sync)
    KubeDeployTools::Logger.logger = logger
  end

  it "fails to read invalid YAML files" do
    deploy = KubeDeployTools::Deploy.new(
      input_path: KUBERNETES_MANIFESTS_INVALID_NGINX,
      kubectl: kubectl,
    )
    expect do
      deploy.read_resources
    end.to raise_error(/cannot be parsed/)
  end

  it "reads valid YAML files" do
    deploy = KubeDeployTools::Deploy.new(
      input_path: KUBERNETES_MANIFESTS_TEST_NGINX,
      kubectl: kubectl,
    )
    resources = deploy.read_resources
    expect(resources.find { |resource| resource.definition["kind"] == "Deployment" }).to_not be_nil
  end

  it "predeploys resources" do
    deploy = KubeDeployTools::Deploy.new(
      input_path: KUBERNETES_MANIFESTS_TEST_NGINX,
      kubectl: kubectl,
    )
    resources = deploy.read_resources
    expect(resources.find { |resource| resource.definition["kind"] == "Deployment" }).to_not be_nil
    expect(resources.find { |resource| resource.definition["kind"] == "Service" }).to_not be_nil
    expect(resources.find { |resource| resource.definition["kind"] == "Namespace" }).to_not be_nil

    # Namespaces are deployed before Services
    expect(kubectl).to receive(:run).with('apply', '-f', be_kubernetes_resource_of_kind('Namespace'), any_args).ordered
    # Services are deployed before Deployments
    expect(kubectl).to receive(:run).with('apply', '-f', be_kubernetes_resource_of_kind('Service'), any_args).ordered
    expect(kubectl).to receive(:run).with('apply', '-f', be_kubernetes_resource_of_kind('Deployment'), any_args).ordered
    deploy.run
  end

  context "include and exlude tags" do
    let (:resources){
      Dir.mktmpdir do |tmp_dir|
        FileUtils.touch("#{tmp_dir}/cron.yaml")
        FileUtils.touch("#{tmp_dir}/dep.yaml")
        FileUtils.touch("#{tmp_dir}/ingress.yaml")
        FileUtils.touch("#{tmp_dir}/service.yaml")
        FileUtils.mkdir("#{tmp_dir}/socks-server")
        FileUtils.touch("#{tmp_dir}/socks-server/socks-server.yaml")

        deploy = KubeDeployTools::Deploy.new(
          input_path: tmp_dir,
          kubectl: kubectl,
          glob_files: options.glob_files,
        )

        deploy.select_resources(options.glob_files)
      end
    }

    context "when no include and exclude tags are specified" do
      let(:options) { parse(target: target, environment: environment, build: build_number) }

      it "loads all files" do
        expect(resources.length).to eq(6)
        expect(resources).to include(match /cron.yaml/)
        expect(resources).to include(match /dep.yaml/)
        expect(resources).to include(match /ingress.yaml/)
        expect(resources).to include(match /service.yaml/)
        expect(resources).to include(match /socks-server/)
        expect(resources).to include(match /socks-server\/socks-server.yaml/)
      end
    end

    context "when only include tag is specified" do
      let(:options) { parse(target: target, environment: environment, build: build_number, include: '**/ingress*') }

      it "load include files" do
        expect(resources.length).to eq(1)
        expect(resources).to include(match /ingress.yaml/)
      end
    end

    context "when only exclude tag is specified" do
      let(:options) { parse(target: target, environment: environment, build: build_number, exclude: '**/ser*') }

      it "do not load exclude files" do
        expect(resources.length).to eq(5)
        expect(resources).to include(match /cron.yaml/)
        expect(resources).to include(match /dep.yaml/)
        expect(resources).to include(match /ingress.yaml/)
        expect(resources).not_to include(match /service.yaml/)
        expect(resources).to include(match /socks-server/)
        expect(resources).to include(match /socks-server\/socks-server.yaml/)
      end
    end

    context "when both include and exclude tags are specified" do
      let(:options) { parse(target: target, environment: environment, build: build_number, include: '**/*', exclude: '**/socks-server/*') }

      it "load include files and do not load exclude files" do
        expect(resources.length).to eq(5)
        expect(resources).to include(match /cron.yaml/)
        expect(resources).to include(match /dep.yaml/)
        expect(resources).to include(match /ingress.yaml/)
        expect(resources).to include(match /service.yaml/)
        expect(resources).to include(match /socks-server/)
        expect(resources).not_to include(match /socks-server\/socks-server.yaml/)
      end
    end
  end
end

describe KubeDeployTools::Deploy::Optparser do
  it "accepts --target, --environment, --build" do
    options = parse(target: target, environment: environment, build: build_number)
    expect(options.target).to match(target)
    expect(options.environment).to match(environment)
    expect(options.build_number).to match(build_number)
  end

  it "accepts --from-files, --context" do
    from_files = 'bogus/path/'
    context = 'bogus@k8s.context'
    options = parse('from-files': from_files, context: context)
    expect(options.from_files).to match(from_files)
    expect(options.context).to match(context)
  end

  it "fails without flags" do
    expect { KubeDeployTools::Deploy::Optparser.new.parse({}) }.to raise_error(/Expect/)
  end
end

