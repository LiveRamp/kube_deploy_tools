require 'kube_deploy_tools/shellrunner'

describe KubeDeployTools::Shellrunner do
  # Mock logger
  let(:logger) { instance_double('logger') }

  # Mock Open3 captured output
  let(:status) { double("status", success?: true) }
  let(:err) { nil }
  let(:stdoutput) { 'bogus command output' }
  let(:captured_output) { [stdoutput, err, status] }

  # Test setup
  let(:shellrunner) { KubeDeployTools::Shellrunner.new }
  let(:cmd) { ['bogus', 'command'] }

  before(:example) do
    KubeDeployTools::Logger.logger = logger
  end

  context "where the command fails" do

    # Mock Open3 captured output
    let(:err) { 'my err' }
    let(:status) { double("status", success?: false) }

    it "raises an error with the command ran" do
      allow(Open3).to receive(:capture3).with(*cmd).and_return(captured_output)
      expect do
        shellrunner.check_call(*cmd)
      end.to raise_error(include(cmd.join(' ')))
    end

    it "prints the command" do
      allow(Open3).to receive(:capture3).with(*cmd).and_return(captured_output)
      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)

      # Log the failed command and the error
      expect(logger).to receive(:warn).with(/command failed/).once
      expect(logger).to receive(:warn).with(err).once

      shellrunner.run_call(*cmd)

      # Don't log anything
      expect(logger).not_to receive(:warn)
      shellrunner.run_call(*cmd, print_cmd: false)
    end
  end
end
