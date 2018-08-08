require 'kube_deploy_tools/deploy'
require 'kube_deploy_tools/deploy/options'

KUBERNETES_MANIFESTS_INVALID_NGINX="spec/resources/kubernetes/invalid-nginx/"
KUBERNETES_MANIFESTS_TEST_NGINX="spec/resources/kubernetes/test-nginx/"
KUBERNETES_MANIFESTS_COMBINED_NGINX="spec/resources/kubernetes/combined-nginx/"
CONTEXT="fake.context.k8s"
def make_argv(ops)
  ops.flat_map do |k,v|
    ["--#{k}", v]
  end
end

def parse(ops)
  KubeDeployTools::Deploy::Optparser.new.parse(make_argv(ops))
end

artifact = 'bogus-target-cluster-prod'
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

  it "reads YAML files with multiple resources" do
    deploy = KubeDeployTools::Deploy.new(
      input_path: KUBERNETES_MANIFESTS_COMBINED_NGINX,
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

  context "helper functions" do
    # Mock shellrunner
    let(:status) { double(:status, success?: true) }

    it 'gets the kube namespace' do
      kubectl_output = ''
      KubeDeployTools::Shellrunner.shellrunner = instance_double("shellrunner", :check_call => [kubectl_output, nil, status])
      actual = KubeDeployTools::Deploy.kube_namespace(context: 'fake-context')
      expected = 'default'
      expect(actual).to eq(expected)

      kubectl_output = 'some-other-namespace'
      KubeDeployTools::Shellrunner.shellrunner = instance_double("shellrunner", :check_call => [kubectl_output, nil, status])
      actual = KubeDeployTools::Deploy.kube_namespace(context: 'fake-context')
      expected = kubectl_output
      expect(actual).to eq(expected)

      kubeconfig = 'fake-kubeconfig'
      KubeDeployTools::Shellrunner.shellrunner = instance_double("shellrunner", :check_call => [kubectl_output, nil, status])
      expect(KubeDeployTools::Shellrunner.shellrunner).to receive(:check_call).with(any_args, "--kubeconfig=#{kubeconfig}").once
      KubeDeployTools::Deploy.kube_namespace(context: 'fake-context', kubeconfig: kubeconfig)
    end
  end
end

describe KubeDeployTools::Deploy::Optparser do

  it "fails without flags" do
    expect { KubeDeployTools::Deploy::Optparser.new.parse({}) }.to raise_error(/Expect/)
  end

  it "accepts (--artifact, --build) or --from-files to fetch deploy artifact" do
    options = parse(
      artifact: artifact,
      build: build_number,
      context: CONTEXT)
    expect(options.artifact).to match(artifact)
    expect(options.build_number).to match(build_number)
    expect(options.context).to match(CONTEXT)

    from_files = 'bogus/path/'
    options = parse('from-files': from_files,
      context: CONTEXT)
    expect(options.from_files).to match(from_files)
    expect(options.context).to match(CONTEXT)
  end

end

