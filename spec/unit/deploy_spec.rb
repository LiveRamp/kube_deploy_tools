require 'kube_deploy_tools/deploy'
require 'kube_deploy_tools/deploy/options'
require 'kube_deploy_tools/formatted_logger'

KUBERNETES_MANIFESTS_INVALID_NGINX="spec/resources/kubernetes/invalid-nginx/"
KUBERNETES_MANIFESTS_TEST_NGINX="spec/resources/kubernetes/test-nginx/"
CONTEXT="fake.context.k8s"

describe KubeDeployTools::Deploy do
  let(:logger) { KubeDeployTools::FormattedLogger.build(context: CONTEXT) }

  # Mock kubectl
  let(:status) { double(:status, success?: true) }
  let(:stdoutput) { 'kubectl apply mock output' }
  let(:kubectl) { instance_double("kubectl", :run => [stdoutput, nil, status]) }

  it "fails to read invalid YAML files" do
    deploy = KubeDeployTools::Deploy.new(
      input_path: KUBERNETES_MANIFESTS_INVALID_NGINX,
      logger: logger,
      kubectl: kubectl,
    )
    expect do
      deploy.read_resources
    end.to raise_error(/cannot be parsed/)
  end

  it "reads valid YAML files" do
    deploy = KubeDeployTools::Deploy.new(
      input_path: KUBERNETES_MANIFESTS_TEST_NGINX,
      logger: logger,
      kubectl: kubectl,
    )
    resources = deploy.read_resources
    expect(resources.find { |resource| resource.content["kind"] == "Deployment" }).to_not be_nil
  end

  it "predeploys resources" do
    deploy = KubeDeployTools::Deploy.new(
      input_path: KUBERNETES_MANIFESTS_TEST_NGINX,
      logger: logger,
      kubectl: kubectl,
    )
    resources = deploy.read_resources
    expect(resources.find { |resource| resource.content["kind"] == "Deployment" }).to_not be_nil
    expect(resources.find { |resource| resource.content["kind"] == "Service" }).to_not be_nil
    expect(resources.find { |resource| resource.content["kind"] == "Namespace" }).to_not be_nil

    # Namespaces are deployed before Services
    expect(kubectl).to receive(:run).with('apply', '-f', include('ns'), any_args).ordered
    # Services are deployed before Deployments
    expect(kubectl).to receive(:run).with('apply', '-f', include('service'), any_args).ordered
    expect(kubectl).to receive(:run).with('apply', '-f', include('dep'), any_args).ordered
    deploy.run
  end

  describe KubeDeployTools::Deploy::Optparser do
    def make_argv(ops)
      ops.flat_map do |k,v|
        ["--#{k}", v]
      end
    end
    def parse(ops)
      KubeDeployTools::Deploy::Optparser.new.parse(make_argv(ops))
    end

    it "accepts --target, --environment, --build" do
      target = 'bogus-target-cluster'
      environment = 'staging'
      build_number = '12345'
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
end

