require 'digest'
require 'etc'
require 'time'
require 'erb'
require 'yaml'

require 'kube_deploy_tools/shellrunner'

module KubeDeployTools
  # Default method to derive a tag name based on the current environment.
  # An image is tagged for the current branch, git sha, and Jenkins build id.
  def self.tag_from_local_env
    codestamp = (ENV['GIT_COMMIT'] || `git rev-parse HEAD`.rstrip)[0...7]

    branch = ENV['GIT_BRANCH'] || `git rev-parse --abbrev-ref HEAD`.rstrip
    if branch.start_with?('origin/')
      branch = branch['origin/'.size..-1]
    end

    # From the Docker docs:
    # "A tag name must be valid ASCII and may contain lowercase and uppercase
    # letters, digits, underscores, periods and dashes. A tag name may not
    # start with a period or a dash and may contain a maximum of 128
    # characters."
    branch = branch.gsub(/[^A-Za-z0-9_\.\-\.]/, '_')
    if branch[0] == '.' || branch[0] == '-'
      # We could do something more clever here. Not worth it right now.
      raise "First char of branch name must be alphanumeric: #{branch}"
    end

    # Include the Jenkins build ID, in the case that there are
    # multiple builds at the same git branch and git commit,
    # but with different dependencies.
    build = ENV.fetch('BUILD_ID', 'dev')[0...5]

    # Docker maximum tag length is 128 characters long.
    # Kubernetes maximum label length is 63 characters long. Go with that.
    # 63 >= max 49 char branch + 1 char hyphen + 7 char codestamp + max 5 char build id
    "#{branch[0...49]}-#{codestamp}-#{build}"
  end

  REGISTRIES = {
    'artifactory' => {
      'driver' => 'login',
      'prefix' => '***REMOVED***:6555',
      'username_var' => 'ARTIFACTORY_USERNAME',
      'password_var' => 'ARTIFACTORY_PASSWORD',
    },
    'aws' => {
      'driver' => 'aws',
      'prefix' => '***REMOVED***',
      'region' => 'us-west-2',
    },
    'local' => {
      'driver' => 'noop',
      'prefix' => 'local-registry',
    },
    'colo' => {
      'driver' => 'aws',
      'prefix' => '***REMOVED***',
      'region' => 'us-west-2',
    },
    'gcp' => {
      'driver' => 'gcp',
      'prefix' => '***REMOVED***',
    }
  }.freeze

  PREFIX_TO_REGISTRY = Hash[REGISTRIES.map {|reg, info| [info['prefix'], reg]}]

  DEFAULT_REGISTRY = REGISTRIES['aws']['prefix']

  CLUSTERS = YAML.load(File.read(
    File.join(File.dirname(__FILE__), '../../clusters.yml'))).freeze

  def self.resolve_cluster_config(target, environment)
    target_config = CLUSTERS.fetch(target) do
      raise "#{target} is not a valid target. Please choose a value among: " \
        "#{CLUSTERS.keys}."
    end

    target_config.fetch(environment) do
      raise "#{environment} is not a valid environment for #{target}. " \
        "Please choose a value among: #{target_config.keys}."
    end
  end

  def self.kube_context(target:, environment:)
    b = binding
    b.local_variable_set(:username, ENV.fetch('USER', Etc.getlogin))
    renderer = ERB.new(
      resolve_cluster_config(target, environment)['kube_context']
    )

    renderer.result(b)
  end

  def self.kube_namespace(context:)
    namespace, _, _ = Shellrunner.check_call('kubectl', 'config', 'view', '--minify', "--output=jsonpath={..namespace}", "--context=#{context}")
    namespace = 'default' if namespace.to_s.empty?

    namespace
  end
end
