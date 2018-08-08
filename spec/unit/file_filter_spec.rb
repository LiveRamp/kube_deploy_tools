require 'tmpdir'

require 'kube_deploy_tools/file_filter'

describe KubeDeployTools::FileFilter do
  let(:logger) { KubeDeployTools::FormattedLogger.build }

  before(:example) do
    KubeDeployTools::Logger.logger = logger
  end

  describe '.filter_files' do
    let (:filtered_files){
      Dir.mktmpdir do |tmp_dir|
        FileUtils.touch("#{tmp_dir}/socks-server-decoy.yaml")
        FileUtils.mkdir("#{tmp_dir}/socks-server")
        FileUtils.touch("#{tmp_dir}/socks-server/socks-server.yaml")
        FileUtils.mkdir("#{tmp_dir}/socks-server/support")
        FileUtils.touch("#{tmp_dir}/socks-server/support/extra.yaml")

        subject.filter_files(filters: filters, files_path: tmp_dir)
      end
    }

    context "with no filters" do
      let(:filters) { [] }

      it "loads all files" do
        expect(filtered_files).to include(match /socks-server-decoy.yaml/)
        expect(filtered_files).to include(match /socks-server/)
        expect(filtered_files).to include(match /socks-server\/socks-server.yaml/)
        expect(filtered_files).to include(match /socks-server\/support$/)
        expect(filtered_files).to include(match /socks-server\/support\/extra.yaml/)
        expect(filtered_files.length).to eq(5)
      end
    end

    context "with only include_files filters" do
      let(:filters) { [['include_files', '**/socks-server/*']] }

      it "only loads files matching include filters" do
        expect(filtered_files).to include(match /socks-server\/socks-server.yaml/)
        expect(filtered_files).to include(match /socks-server\/support$/)
        expect(filtered_files.length).to eq(2)
      end
    end

    context "with only exclude_files filters" do
      let(:filters) { [['exclude_files', '**/socks-server*']] }

      it "excludes only the files matching exclude filters" do
        expect(filtered_files).not_to include(match /socks-server-decoy.yaml/)
        expect(filtered_files).not_to include(match /socks-server$/)
        expect(filtered_files).not_to include(match /socks-server\/socks-server.yaml/)
        expect(filtered_files).to include(match /socks-server\/support$/)
        expect(filtered_files).to include(match /socks-server\/support\/extra.yaml/)
        expect(filtered_files.length).to eq(2)
      end
    end

    context 'with only include_dir filters' do
      let(:filters) { [['include_dir', 'socks-server/']] }

      it 'includes only the specified directory contents and its subdirectories' do
        expect(filtered_files).not_to include(match /socks-server-decoy.yaml/)
        expect(filtered_files).to include(match /socks-server\/socks-server.yaml/)
        expect(filtered_files).to include(match /socks-server\/support$/)
        expect(filtered_files).to include(match /socks-server\/support\/extra.yaml/)
        expect(filtered_files.length).to eq(3)
      end
    end

    context 'with only exclude_dir filters' do
      let(:filters) { [['exclude_dir', 'socks-server/']] }

      it 'excludes only the specified directory contents and its subdirectories' do
        expect(filtered_files).to include(match /socks-server-decoy.yaml/)
        expect(filtered_files).to include(match /socks-server$/)
        expect(filtered_files.length).to eq(2)
      end
    end

    context "with both include and exclude filters" do
      let(:filters) { [['include_dir', 'socks-server/'], ['exclude_dir', 'socks-server/support/']] }

      it "starts with an empty set and adds/removes files based on the order in which the filters are declared" do
        expect(filtered_files).not_to include(match /socks-server-decoy.yaml/)
        expect(filtered_files).to include(match /socks-server\/socks-server.yaml/)
        expect(filtered_files).to include(match /socks-server\/support$/)
        expect(filtered_files).not_to include(match /socks-server\/support\/extra.yaml/)
        expect(filtered_files.length).to eq(2)
      end
    end

    context 'with a dir filter with no wildcards' do
      context 'that is the relative path to a directory starting from files_path' do
        let(:filters) { [['include_dir', 'socks-server/support/']] }

        it 'matches the files in the subdirectory' do
          expect(filtered_files).to include(match /socks-server\/support\/extra.yaml/)
          expect(filtered_files.length).to eq(1)
        end
      end

      context 'that is not a relative path to any directory starting from files_path' do
        let(:filters) { [['include_dir', 'support/']] }

        it 'does not match any directories' do
          expect(filtered_files).not_to include(match /socks-server\/support/)
          expect(filtered_files.length).to eq(0)
        end
      end
    end

    context 'with a dir filter with wildcards' do
      let(:filters) { [['include_dir', '**/*/socks-server/**']] }

      it 'ignores the leading and trailing globs in the argument' do
        expect(filtered_files).not_to include(match /socks-server-decoy.yaml/)
        expect(filtered_files).to include(match /socks-server\/socks-server.yaml/)
        expect(filtered_files).to include(match /socks-server\/support$/)
        expect(filtered_files).to include(match /socks-server\/support\/extra.yaml/)
        expect(filtered_files.length).to eq(3)
      end
    end
  end
end
