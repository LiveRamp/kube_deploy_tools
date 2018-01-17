require 'tempfile'

require 'kube_deploy_tools/built_artifacts_file'

describe KubeDeployTools::BuiltArtifactsFile do
  file_name = 'test.yaml'

  it 'does not fail when passed an empty file' do
    built_artifacts_file = KubeDeployTools::BuiltArtifactsFile.new(file_name)
    expect(built_artifacts_file.images).to eq(Set.new)
    expect(built_artifacts_file.build_id).to be_nil
    expect(File.exists?(file_name)).to be false
  end

  it 'ensures uniqueness to new values' do 
    build_id = 1234
    images = ['aws-test', 'gcr-my', 'artifactory-values', 'aws-test']
    test_yaml = {'build_id' => build_id, 'images' => images}.to_yaml

    File.open(file_name, 'w') do |file|
      file.write(test_yaml)
    end

    built_artifacts_file = KubeDeployTools::BuiltArtifactsFile.new(file_name)
    expect(built_artifacts_file.images.size).to eq(3)
    expect(built_artifacts_file.build_id).to eq(build_id)

    File.open(file_name, 'w+') do |file|
      built_artifacts_file.images.add 'gcr-my'
      built_artifacts_file.write(file)
      expect(built_artifacts_file.images.size).to eq(3)

      built_artifacts_file.images.add 'test'
      built_artifacts_file.write(file)
    end

    expect(built_artifacts_file.images.size).to eq(4)

    # Need to remove the created file
    File.delete(file_name)
    expect(File.exists?(file_name)).to be false
  end
end
