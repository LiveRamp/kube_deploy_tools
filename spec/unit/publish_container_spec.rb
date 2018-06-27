require 'fileutils'
require 'securerandom'
require 'tmpdir'

require 'kube_deploy_tools/publish_container'

BUILT_ARTIFACTS_PATH = 'build'

describe KubeDeployTools::PublishContainer do
  # Mock shellrunner
  let(:status) { double(:status, success?: true) }
  let(:stdoutput) { 'fake stdoutput' }
  let(:shellrunner) { instance_double("shellrunner", :run_call => [stdoutput, nil, status]) }

  before(:example) do
    KubeDeployTools::Shellrunner.shellrunner = shellrunner
  end

  describe 'publish' do
    let(:publisher) do
      KubeDeployTools::PublishContainer.new(
        'my-registry',
        remote_registry,
        images,
        'releaseTag'
      )
    end
    let(:images) { ['project1'] }

    context 'local' do
      let(:remote_registry) { ['local'] }

      it 'tags properly' do
        expect(shellrunner).to(receive(:check_call).with(
          'docker', 'tag', 'my-registry/project1:latest', 'local-registry/project1:releaseTag'
          ).once)

        publisher.publish
      end
    end

    context 'artifactory' do
      let(:remote_registry) { ['artifactory'] }
      let(:images) { ['project1', 'project2', 'project3'] }

      it 'works' do
        fake_username = 'bill'
        fake_password = 'definitely_not_aaron'

        # -e none should be stripped if it is there.
        expect(shellrunner).to receive(:check_call).with('docker', 'tag', any_args).exactly(images.length).times
        expect(shellrunner).to receive(:check_call).with('docker', 'login', '--username', fake_username, '--password', fake_password, '***REMOVED***:6555', print_cmd: false).once

        expect(shellrunner).to receive(:check_call).with('docker', 'push', any_args).exactly(images.length).times

        ENV['ARTIFACTORY_USERNAME'] = fake_username
        ENV['ARTIFACTORY_PASSWORD'] = fake_password
        publisher.publish
      end
    end

    context 'aws' do
      let(:remote_registry) { ['aws'] }
      let(:images) { ['project1', 'project2', 'project3'] }

      it 'works' do
        # -e none should be stripped if it is there.
        expect(shellrunner).to receive(:check_call).with('docker', 'tag', any_args).exactly(images.length).times
        expect(shellrunner).to receive(:check_call).with('docker', 'login', '-u', 'AWS', '-p', 'paws', 'https://***REMOVED***', print_cmd: false).once

        expect(shellrunner).to receive(:check_call).with('aws', 'ecr', 'get-login', '--region', 'us-west-2') do
          'docker login -u AWS -p paws -e none https://***REMOVED***'
        end
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
      let(:remote_registry) { ['gcp'] }
      let(:emptyActivation) { '' }

      it 'works' do
        expect(shellrunner).to receive(:check_call).with('docker', 'tag', any_args).exactly(images.length).times
        expect(shellrunner).to receive(:run_call).with('gcloud', 'config', 'list','account','--format', "value(core.account)") do
          [emptyActivation, nil, double(:status, success?: false)]
        end
        ENV['GOOGLE_APPLICATION_CREDENTIALS'] = '/Users/ops/***REMOVED***.json'
        expect(shellrunner).to receive(:run_call).with('gcloud', 'auth', 'activate-service-account', '--key-file', ENV['GOOGLE_APPLICATION_CREDENTIALS']).once
        expect(shellrunner).to receive(:check_call).with('gcloud', 'docker', '-a', print_cmd: false).once
        expect(shellrunner).to receive(:check_call).with('docker', 'push', '***REMOVED***/project1:releaseTag').once

        publisher.publish
        FileUtils.rm_rf(BUILT_ARTIFACTS_PATH) # Removes build/kubernetes/images.yaml created in update_built_artifacts
      end

    end

    context 'multi registry' do
      let(:remote_registry) { ['aws', 'gcp'] }

      it 'works' do
        expect(shellrunner).to receive(:check_call).with('docker', 'tag', any_args).exactly(images.length).times
        expect(shellrunner).to receive(:check_call).with('docker', 'login', '-u', 'AWS', '-p', 'paws', 'https://***REMOVED***', print_cmd: false).once
        expect(shellrunner).to receive(:check_call).with('aws', 'ecr', 'get-login', '--region', 'us-west-2') do
          'docker login -u AWS -p paws -e none https://***REMOVED***'
        end
        expect(shellrunner).to receive(:check_call).with('docker', 'tag', any_args).exactly(images.length).times
        expect(shellrunner).to receive(:check_call).with('gcloud', 'docker', '-a', print_cmd: false).once
        expect(shellrunner).to receive(:check_call).with('docker', 'push', '***REMOVED***/project1:releaseTag').exactly(images.length).times
        expect(shellrunner).to receive(:check_call).with('docker', 'push', '***REMOVED***/project1:releaseTag').exactly(images.length).times

        publisher.publish
        FileUtils.rm_rf(BUILT_ARTIFACTS_PATH) # Removes build/kubernetes/images.yaml created in update_built_artifacts
      end
    end

    context 'artifacts file behavior' do
      let(:remote_registry) { ['aws'] }
      file_name = "test_#{SecureRandom.uuid}.yaml"

      after(:context) do
        FileUtils.rm(file_name)
      end

      image_a = KubeDeployTools::PublishContainer::Image.new('aws', 'test', 'a')
      image_b = KubeDeployTools::PublishContainer::Image.new('aws', 'test', 'b')
      images_to_push = [image_a, image_b]

      # Need to create the file object since it is assumed the file exists
      # otherwise the r+ file permissions will fail to add to the file
      file_object = File.open(file_name, File::CREAT) {}

      it 'creates a new artifacts file when one does not already exist' do
        file_object = File.open(file_name, 'r+')
        publisher.send :update_built_artifacts, images_to_push, file_object
        expect(File.exists?(file_name)).to be true
        file_object.close

        config = YAML.load_file(file_name)
        expect(config['build_id']).to_not be_nil
        expect(config['images']).to_not be_nil
      end

      it 'updates the artifacts file in-place if BUILD_ID is the same as what is in the file' do
        config = YAML.load_file(file_name)
        old_build_id = config['build_id']
        expect(config['images'].size).to eq(images_to_push.size)
        expect(old_build_id.nil?).to_not be_nil

        image_to_add = [KubeDeployTools::PublishContainer::Image.new('aws', 'test', 'c')]
        file_object = File.open(file_name, 'r+')
        publisher.send :update_built_artifacts, image_to_add, file_object
        file_object.close
        new_config = YAML.load_file(file_name)

        expect(new_config['build_id']).to eq(old_build_id)
        expect(new_config['images'].size).to eq(images_to_push.size + 1)
      end

      it 'resets the artifacts file in-place with a blank list of images if BUILD_ID has changed' do
        config = YAML.load_file(file_name)
        old_build_id = config['build_id']
        expect(old_build_id.nil?).to be false

        ENV['BUILD_ID'] = 'test_local'
        file_object = File.open(file_name, 'r+')
        publisher.send :update_built_artifacts, [], file_object
        file_object.close

        new_config = YAML.load_file(file_name)

        expect(new_config['build_id']).to_not eq(old_build_id)
        expect(new_config['build_id']).to eq('test_local')
        expect(new_config['images'].size).to eq(0)
      end
    end
  end
end
