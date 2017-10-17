require 'etc'
require 'time'

# Default method to derive a tag name based on the current environment.
def tag_from_local_env
  timestamp = DateTime.now.strftime('%j.%H.%M.%S')
  "#{ENV['GIT_BRANCH'] || 'LOCAL'}-#{ENV['GIT_COMMIT'] || timestamp}"
end

DEFAULT_REGISTRY = '***REMOVED***'

DEFAULT_FLAGS = {
  'image_tag' => tag_from_local_env,
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
