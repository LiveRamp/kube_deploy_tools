require 'kube_deploy_tools/shellrunner'
require 'kube_deploy_tools/formatted_logger'

describe KubeDeployTools::Shellrunner do
  let(:logger) { KubeDeployTools::FormattedLogger.build(context: CONTEXT) }

  # Mock shellrunner
  let(:status) { double(:status, success?: true) }
  let(:stdoutput) { 'bogus command output' }

  context "where the command fails" do
    let(:status) { double(:status, success?: false) }

    it "raises an error with the command ran" do
      shellrunner = KubeDeployTools::Shellrunner.new(logger: logger)

      cmd = ['bogus', 'command']
      expect(shellrunner).to receive(:run_call).with(*cmd).and_return([stdoutput, nil, status])

      expect do
        shellrunner.check_call(*cmd)
      end.to raise_error(include(cmd.join(' ')))
    end
  end
end
