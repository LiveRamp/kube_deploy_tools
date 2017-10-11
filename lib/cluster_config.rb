CLUSTERS = {
  'local' => {
    'staging' => {
      'kube_context' => 'minikube',
      'flags' => {
        'cloud' => 'local',
        'image_tag' => 'latest',
        'kubernetes_major_version' => '1',
        'kubernetes_minor_version' => '7',
        'tag' => '<%= DateTime.now.strftime "%j.%H.%M.%S" %>',
        'image_registry' => 'local-registry',
        'pull_policy' => 'Never'
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
        'image_registry' => '***REMOVED***.dkr.ecr.us-east-1.amazonaws.com',
        'kubernetes_major_version' => '1',
        'kubernetes_minor_version' => '7',
        'pull_policy' => 'Always',
      }
    },
    'staging' => {
      'kube_context' => '<%= username %>@staging.us-east-1.k8s.***REMOVED***',
      'flags' => {
        'cloud' => 'aws',
        'image_registry' => '***REMOVED***.dkr.ecr.us-east-1.amazonaws.com',
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
        'image_registry' => '***REMOVED***.dkr.ecr.us-east-1.amazonaws.com',
        'kubernetes_major_version' => '1',
        'kubernetes_minor_version' => '7',
        'pull_policy' => 'Always',
      }
    },
    'staging' => {
      'kube_context' => '<%= username %>@staging.service',
      'flags' => {
        'cloud' => 'colo',
        'image_registry' => '***REMOVED***.dkr.ecr.us-east-1.amazonaws.com',
        'kubernetes_major_version' => '1',
        'kubernetes_minor_version' => '7',
        'pull_policy' => 'Always',
      }
    }
  }
}
