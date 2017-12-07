require 'kube_deploy_tools/publish_container'

describe KubeDeployTools::PublishContainer do
  # Mock shellrunner
  let(:status) { double(:status, success?: true) }
  let(:stdoutput) { 'fake stdoutput' }
  let(:shellrunner) { instance_double("shellrunner", :run_call => [stdoutput, nil, status]) }

  describe 'publish' do
    let(:publisher) do
      KubeDeployTools::PublishContainer.new(
        'my-registry',
        remote_registry,
        images,
        'releaseTag',
        shellrunner: shellrunner,
      )
    end
    let(:images) { ['project1'] }

    context 'local' do
      let(:remote_registry) { 'local' }

      it 'tags properly' do
        expect(shellrunner).to(receive(:check_call).with(
          'docker', 'tag', 'my-registry/project1:latest', 'local-registry/project1:releaseTag'
          ).once)

        publisher.publish
      end
    end

    context 'aws' do
      let(:remote_registry) { 'aws' }
      let(:images) { ['project1', 'project2', 'project3'] }

      it 'works' do
        expect(shellrunner).to receive(:check_call).with('docker', 'tag', any_args).exactly(images.length).times

        expect(shellrunner).to receive(:check_call).with('aws', 'ecr', 'get-login', '--region', 'us-west-2') do
          'docker login -u AWS -p paws -e none https://***REMOVED***'
        end
        # -e none should be stripped if it is there.
        expect(shellrunner).to receive(:check_call).with('docker', 'login', '-u', 'AWS', '-p', 'paws', 'https://***REMOVED***').once

        expect(shellrunner).to receive(:run_call).with('aws', 'ecr', 'describe-repositories', '--repository-names', 'project1', '--region', 'us-west-2') do
          [stdoutput, nil, double(:status, success?: false)]
        end
        expect(shellrunner).to receive(:check_call).with('aws', 'ecr', 'create-repository', '--repository-name', 'project1', '--region', 'us-west-2').once
        expect(shellrunner).to receive(:run_call).with('aws', 'ecr', 'describe-repositories', any_args).exactly(images.length - 1).times

        expect(shellrunner).to receive(:check_call).with('docker', 'push', any_args).exactly(images.length).times

        publisher.publish
      end
    end

    context 'gcp' do
      let(:remote_registry) { 'gcp' }

      it 'works' do
        expect(shellrunner).to receive(:check_call).with('docker', 'tag', any_args).exactly(images.length).times
        expect(shellrunner).to receive(:check_call).with('gcloud', 'docker', '-a').once
        expect(shellrunner).to receive(:check_call).with('docker', 'push', 'gcr.io/pippio-production/project1:releaseTag').once

        publisher.publish
      end
    end

  end
end
