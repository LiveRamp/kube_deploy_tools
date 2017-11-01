require 'tmpdir'
require 'kube_deploy_tools/templater'
require 'kube_deploy_tools/templater/options'

TEMPLATE_FILENAME="example.yaml.erb"
TEMPLATE_FILEPATH="spec/resources/kubernetes/template-example/#{TEMPLATE_FILENAME}"

describe KubeDeployTools::Templater do
  it "writes to output file" do
    Dir.mktmpdir do |tmp_dir|
      templater = KubeDeployTools::Templater.new
      file = File.join(tmp_dir, "example.yaml")
      templater.template_to_file(TEMPLATE_FILEPATH, {'foo' => 'bar'}, file)
      expect(Dir["#{tmp_dir}/*"]).to eq([file])
      expect(File.read(file).strip).to eq("Hello bar")
    end
  end

  describe KubeDeployTools::Templater::Optparser do
    def make_argv(ops)
      ops.flat_map do |k,v|
        ["--#{k}", v]
      end
    end
    def parse(ops)
      KubeDeployTools::Templater::Optparser.new.parse(make_argv(ops))
    end
    it "accepts --template" do
      options = parse(template: TEMPLATE_FILEPATH)
      expect(options.template).to match(TEMPLATE_FILENAME)
    end
    it "fails without --template" do
      expect { parse({}) }.to raise_error(/Must provide --template/)
    end
    it "fails if --template doesn't exist" do
      expect do
        parse(template: "bogus/path/junk.yaml.erb")
      end.to raise_error(/Cannot find --template/)
    end
  end

  describe KubeDeployTools::Templater::Optparser::Options do
    def req(ops)
      res = KubeDeployTools::Templater::Optparser::Options.new
      ops.each do |k,v|
        res.send("#{k}=", v)
      end
      res.require_options
      res
    end

    it "requires --template" do
      expect { req({}) }.to raise_error(/Must provide --template/)
    end
    it "fails if --template doesn't exist" do
      expect do
        req(template: "bogus/path/nonsense.yaml.erb")
      end.to raise_error(/Cannot find --template/)
    end
  end

end
