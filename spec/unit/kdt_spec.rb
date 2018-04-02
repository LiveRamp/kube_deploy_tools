require 'kube_deploy_tools/kdt'

describe KubeDeployTools::Kdt do
    it 'gets the name of the binary files except for "kdt"' do
        path = File.expand_path('../resources/bin', __dir__)
        kdt = KubeDeployTools::Kdt.new(path, [])

        expect(kdt.bins_names).to match_array(['bin_test', 'deploy', 'templater'])
    end

    it 'builds the command to execute the specified bin file' do
        path = File.expand_path('../resources/bin', __dir__)
        kdt = KubeDeployTools::Kdt.new(path, ['bin_test', '-anopt', '--flag', '*'])

        expect(kdt).to receive(:exec).with(
            /\/spec\/resources\/bin\/bin_test/, '-anopt', '--flag', '*')
        kdt.execute!
    end

    it 'raises an error when trying to execute invalid command' do
        path = File.expand_path('../resources/bin', __dir__)
        kdt = KubeDeployTools::Kdt.new(path, ['invalid_command', '-anopt'])

        expect { kdt.execute! }.to raise_error
    end
end
