require 'digest'
require 'etc'
require 'time'
require 'erb'

module KubeDeployTools
  # Default method to derive a tag name based on the current environment.
  def self.tag_from_local_env
    codestamp = `git rev-parse --short=7 HEAD`.rstrip
    # If tree is dirty, take a hash sum of the output of git status -s as well as
    # git diff to try to encapsulate the state of the environment. Uniqueness is
    # all that matters here.
    status = `git status -s`
    if !status.empty?
      diff = `git diff`
      dirty_sum = Digest::MD5.hexdigest(status + diff)
      codestamp += "-dirty#{dirty_sum}"
    end

    branch = ENV['GIT_BRANCH'] || 'LOCAL'
    if branch.start_with?('origin/')
      branch = branch['origin/'.size..-1]
    end
    branch = branch.gsub('/', '_')

    "#{branch}-#{ENV['GIT_COMMIT'] || codestamp}"
  end


  DEFAULT_REGISTRY = '***REMOVED***'

  DEFAULT_FLAGS = {
    'image_tag' => self.tag_from_local_env,
    'tag' => tag_from_local_env,
    'image_registry' => DEFAULT_REGISTRY,
    'username' => Etc.getlogin,
  }.freeze

  CLUSTERS = {
    'local' => {
      'staging' => {
        'kube_context' => 'minikube',
        'flags' => {
          'cloud' => 'local',
          'kubernetes_major_version' => '1',
          'kubernetes_minor_version' => '7',
          'pull_policy' => 'IfNotPresent'
        }
      },
    },
    'gcp' => {
      'prod' => {
        'kube_context' => 'production',
        'flags' => {
          'cloud' => 'gcp',
          'image_registry' => 'gcr.io/pippio-production',
          'kubernetes_major_version' => '1',
          'kubernetes_minor_version' => '6',
          'pull_policy' => 'Always',
        }
      }
    },
    'us-east-1' => {
      'prod' => {
        'kube_context' => '<%= username %>@prod.us-east-1.k8s.***REMOVED***',
        'flags' => {
          'cloud' => 'aws',
          'kubernetes_major_version' => '1',
          'kubernetes_minor_version' => '7',
          'pull_policy' => 'Always',
        }
      },
      'staging' => {
        'kube_context' => '<%= username %>@staging.us-east-1.k8s.***REMOVED***',
        'flags' => {
          'cloud' => 'aws',
          'kubernetes_major_version' => '1',
          'kubernetes_minor_version' => '7',
          'pull_policy' => 'Always',
        }
      }
    },
    'eu-west-1' => {
      'prod' => {
        'kube_context' => '<%= username %>@prod.eu-west-1.k8s.***REMOVED***',
        'flags' => {
          'cloud' => 'aws',
          'kubernetes_major_version' => '1',
          'kubernetes_minor_version' => '7',
          'pull_policy' => 'Always',
        }
      },
      'staging' => {
        'kube_context' => '<%= username %>@staging.eu-west-1.k8s.***REMOVED***',
        'flags' => {
          'cloud' => 'aws',
          'kubernetes_major_version' => '1',
          'kubernetes_minor_version' => '7',
          'pull_policy' => 'Always',
        }
      }
    },
    'colo-service' => {
      'prod' => {
        'kube_context' => '<%= username %>@prod.service',
        'flags' => {
          'cloud' => 'colo',
          'kubernetes_major_version' => '1',
          'kubernetes_minor_version' => '7',
          'pull_policy' => 'Always',
        }
      },
      'staging' => {
        'kube_context' => '<%= username %>@staging.service',
        'flags' => {
          'cloud' => 'colo',
          'kubernetes_major_version' => '1',
          'kubernetes_minor_version' => '7',
          'pull_policy' => 'Always',
        }
      }
    }
  }.freeze

  def self.kube_context(target:, environment:)
    b = binding
    b.local_variable_set(:username, Etc.getlogin)
    renderer = ERB.new(CLUSTERS[target][environment]['kube_context'])

    renderer.result(b)
  end

end

