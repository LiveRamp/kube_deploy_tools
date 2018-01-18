require 'kube_deploy_tools/kubernetes_resource'
require 'kube_deploy_tools/kubernetes_resource/deployment'

KUBERNETES_MANIFESTS_TEST_NGINX="spec/resources/kubernetes/test-nginx"
KUBERNETES_NAMESPACE_RESOURCE="#{KUBERNETES_MANIFESTS_TEST_NGINX}/ns-test.yaml"
KUBERNETES_DEPLOYMENT_RESOURCE="#{KUBERNETES_MANIFESTS_TEST_NGINX}/dep-test-nginx.yaml"
CONTEXT="fake.context.k8s"

describe KubeDeployTools::KubernetesResource do
  let(:logger) { KubeDeployTools::FormattedLogger.build(context: CONTEXT) }

  # Mock kubectl
  let(:status) { double(:status, success?: true) }
  let(:stdoutput) { 'kubectl bogus output' }
  let(:kubectl) { instance_double("kubectl", :run => [stdoutput, nil, status]) }

  # Run test
  let(:definition) { YAML.load_file(filepath) }
  let(:resource) {
    KubeDeployTools::KubernetesResource.build(
      filepath: filepath,
      definition: definition,
      kubectl: kubectl,
    )
  }

  before(:example) do
    KubeDeployTools::Logger.logger = logger
  end

  context 'for a valid Kubernetes Namespace resource file' do
    let (:filepath) { KUBERNETES_NAMESPACE_RESOURCE }
    it 'reads' do
      expect(resource.definition).to eq(definition)
      expect(resource.kind).to eq('Namespace')
      expect(resource.name).to eq('test')
      expect(resource.namespace).to be_nil
      expect(resource.filepath).to be_kubernetes_resource_of_kind('Namespace')
    end
  end


  context 'for a valid Kubernetes Deployment resource file' do
    let (:filepath) { KUBERNETES_DEPLOYMENT_RESOURCE }
    it 'reads' do
        expect(resource.definition).to eq(definition)
        expect(resource.kind).to eq('Deployment')
        expect(resource.name).to eq('test-nginx')
        expect(resource.namespace).to eq('default')
        expect(resource.filepath).to be_kubernetes_resource_of_kind('Deployment')
    end
  end

  describe KubeDeployTools::Deployment do
    let(:logger) { instance_double("logger", :warn => {}) }
    let(:filepath) { KUBERNETES_DEPLOYMENT_RESOURCE }

    it "syncs a Deployment" do
      remote_replicas = 21

      allow(kubectl).to receive(:run).and_return(
        ['{ "spec": { "replicas": 21 } }', nil, status],
      )

      resource.sync
      expect(resource.remote_replicas).to eq(remote_replicas)
    end

    it "warns of replicas mismatch" do
      allow(logger).to receive(:warn)

      resource.found = true

      # Warn
      resource.local_replicas = 5
      resource.remote_replicas = 13
      resource.warn_replicas_mismatch
      expect(logger).to have_received(:warn).with(/mismatch/).once

      # No warning
      resource.local_replicas = 1
      resource.remote_replicas = 1
      resource.warn_replicas_mismatch
      expect(logger).to have_received(:warn).with(/mismatch/).once

      # Warn
      resource.local_replicas = nil
      resource.recorded_replicas = 5
      resource.remote_replicas = 13
      resource.warn_replicas_mismatch
      expect(logger).to have_received(:warn).with(/mismatch/).twice
      expect(logger).to have_received(:warn).with(include("Will scale deployment/#{resource.name} from #{resource.remote_replicas} to 1")).once
    end

  end
end

