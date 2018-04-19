require 'fileutils'
require 'tmpdir'

require 'kube_deploy_tools/deploy_artifact'

LOCAL_ARTIFACT='manifests_local_staging_default'
LOCAL_COMPRESSED_ARTIFACT="#{LOCAL_ARTIFACT}.tar.gz"
REMOTE_ARTIFACT="http://***REMOVED***/artifactory/kubernetes-snapshot-local/FAKEPROJECT/FAKEJOBNUMBER/#{LOCAL_COMPRESSED_ARTIFACT}"
TEST_RESOURCES='spec/resources/'
KUBE_RESOURCE_NEW = 'new.yaml'


describe KubeDeployTools::DeployArtifact do
  before(:example) do
    KubeDeployTools::Shellrunner.shellrunner = shellrunner
  end

  # Mock shellrunner
  let(:status) { double(:status, success?: true) }
  let(:stdoutput) { 'fake stdoutput' }
  let(:shellrunner) { instance_double("shellrunner", :run_call => [stdoutput, nil, status]) }

  context 'when build is latest' do
    fake_html = '<a href="13/">13/</a>    08-Dec-2017 13:10    -
                <a href="19/">19/</a>    19-Dec-2017 12:37    -
                <a href="14/">14/</a>    08-Dec-2017 13:11    -
                <a href="15/">15/</a>    11-Dec-2017 14:21    -
                <a href="18/">18/</a>    14-Dec-2017 14:57    -'

    it "retrieves latest build number according to time" do
      latest_build_number = '19'

      # stub out `curl`
      allow(shellrunner).to receive(:run_call).with('curl', any_args) {
        # Simulate html curling
        [fake_html, nil, status]
      }

      remote_url = KubeDeployTools.get_remote_deploy_artifact_url(
        project: "foo",
        build_number: "latest",
        target: "targetX",
        environment: "prod",
        flavor: "",
      )

      expect(remote_url).to include(latest_build_number)
    end
  end

  it "downloads and uncompresses a remote, compressed deploy artifact" do

    Dir.mktmpdir do |tmp_dir|
      deploy_artifact = KubeDeployTools::DeployArtifact.new(
        input_path: REMOTE_ARTIFACT,
        output_dir_path: tmp_dir,
      )

      local_compressed_artifact = File.join(tmp_dir, LOCAL_COMPRESSED_ARTIFACT)
      local_artifact = File.join(tmp_dir, LOCAL_ARTIFACT)

      # stub out `curl` and `tar -x`
      allow(shellrunner).to receive(:run_call).with('curl', any_args) {
        # Simulate artifact download with tarball copy
        FileUtils.cp(
          File.join(TEST_RESOURCES, LOCAL_COMPRESSED_ARTIFACT),
          local_compressed_artifact,
        )
        [stdoutput, nil, status]
      }

      allow(shellrunner).to receive(:run_call).with('tar', any_args) {
        # Simulate uncompressing tarball with making the directory
        FileUtils.touch("#{local_artifact}/KUBE_RESOURCE_NEW")
        [stdoutput, nil, status]
      }

      path = deploy_artifact.path

      expect(Dir["#{tmp_dir}/*"]).to include(local_compressed_artifact)
      expect(File.directory?(local_artifact)).to be true
      expect(path).to eq(local_artifact)
    end
  end

  it "builds the correct remote artifact URL" do
    allow(Artifactory).to receive(:endpoint).and_return(KubeDeployTools::ARTIFACTORY_ENDPOINT)

    project = 'fake_project'
    build_number = '1234'
    target = 'us-east-1'
    environment = 'prod'
    flavor = 'default'
    url = KubeDeployTools.get_remote_deploy_artifact_url(
      project: project,
      build_number: build_number,
      target: target,
      environment: environment,
      flavor: flavor)
    expect(url).to start_with("#{KubeDeployTools::ARTIFACTORY_ENDPOINT}/#{KubeDeployTools::ARTIFACTORY_REPO}/#{project}/#{build_number}/")
  end

  it 'gets the latest build number' do
    document = '
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<html>
<head><title>Index of kubernetes-snapshot-local/kube_deploy_tools</title>
</head>
<body>
<h1>Index of kubernetes-snapshot-local/kube_deploy_tools</h1>
<pre>Name            Last modified      Size</pre><hr/>
<pre><a href="../">../</a>
<a href="113/">113/</a>             05-Feb-2018 14:37    -
<a href="114/">114/</a>             06-Feb-2018 14:36    -
<a href="115/">115/</a>             06-Feb-2018 17:27    -
<a href="116/">116/</a>             08-Feb-2018 08:45    -
<a href="117/">117/</a>             08-Feb-2018 09:07    -
<a href="118/">118/</a>             08-Feb-2018 09:43    -
<a href="119/">119/</a>             09-Feb-2018 07:51    -
<a href="120/">120/</a>             09-Feb-2018 13:54    -
<a href="121/">121/</a>             12-Feb-2018 17:49    -
<a href="122/">122/</a>             13-Feb-2018 14:25    -
<a href="123/">123/</a>             14-Feb-2018 08:39    -
<a href="124/">124/</a>             16-Feb-2018 14:36    -
<a href="125/">125/</a>             20-Feb-2018 07:16    -
<a href="126/">126/</a>             20-Feb-2018 14:52    -
<a href="127/">127/</a>             20-Feb-2018 15:02    -
<a href="128/">128/</a>             22-Feb-2018 11:20    -
<a href="129/">129/</a>             22-Feb-2018 11:20    -
<a href="dev/">dev/</a>             12-Feb-2018 15:30    -
</pre>
<hr/><address style="font-size:small;">Artifactory/4.15.0 Server at ***REMOVED*** Port 80</address></body></html>
'
    project = 'my-project'
    allow(Artifactory).to receive(:endpoint).and_return(KubeDeployTools::ARTIFACTORY_ENDPOINT)
    expect(shellrunner).to receive(:run_call) do |curl, url|
      expect(url).to start_with("#{KubeDeployTools::ARTIFACTORY_ENDPOINT}/#{KubeDeployTools::ARTIFACTORY_REPO}/#{project}/")
      [document, nil, status]
    end
    latest_build_number = KubeDeployTools.get_latest_build_number(project)
    expect(latest_build_number).to eq('129')

  end

  it "runs pre apply hook" do
    deploy_artifact = KubeDeployTools::DeployArtifact.new(
      input_path: "spec/resources/kubernetes",
      pre_apply_hook: "some/hook.rb"
    )
    expect(shellrunner).to receive(:run_call).with("some/hook.rb", "spec/resources/kubernetes").once
    deploy_artifact.path
  end
end
