require 'templater'
require 'templater/options'
require 'tmpdir'

describe "templater" do
  describe "parse" do
    def make_argv(ops)
      ops.flat_map do |k,v|
        ["--#{k}", v]
      end
    end
    def parse(ops)
      Optparser.new.parse(make_argv(ops))
    end
    it "smoke" do
      options = parse(template: "spec/example.yaml.erb")
      expect(options.template).to match("example.yaml.erb")
    end
    it "fails without template" do
      expect { parse({}) }.to raise_error(/Must provide --template/)
    end
    it "fails if template doesn't exist" do
      expect do
        parse(template: "spec/junk.yaml.erb")
      end.to raise_error(/Cannot find --template/)
    end
  end

  describe "options" do
    def req(ops)
      res = Optparser::TemplaterOptions.new
      ops.each do |k,v|
        res.send("#{k}=", v)
      end
      res.require_options
      res
    end

    describe "basic creation" do
      it "template" do
        expect { req({}) }.to raise_error(/Must provide --template/)
      end
      it "template doesn't exist" do
        expect do
          req(template: "nonsense.yaml.erb")
        end.to raise_error(/Cannot find --template/)
      end
    end
  end

  describe "templating" do
    it "writes to output file" do
      Dir.mktmpdir do |tmp_dir|
        templater = Templater.new
        templater.template_to_file("spec/example.yaml.erb", {'foo' => 'bar'}, File.join(tmp_dir, "example.yaml"))
        file = "#{tmp_dir}/example.yaml"
        expect(Dir["#{tmp_dir}/*"]).to eq([file])
        expect(File.read(file).strip).to eq("Hello bar")
      end
    end
  end
end
