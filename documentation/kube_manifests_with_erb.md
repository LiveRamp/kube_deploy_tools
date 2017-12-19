# Writing Kubernetes manifests with ERB

## kubernetes/ directory
All .yaml and .yaml.erb files in `kubernetes/` are templated out into the
`build/kubernetes/` directory with `bundle exec kdt render_deploys`.

Examples of `kubernetes/` directories with .yaml and .yaml.erb files are
[arbortech/workspace](https://git.***REMOVED***/arbortech/workspace),
[kube-infra](https://git.***REMOVED***/OpsRepos/kube-infra), and
[k8s-reaper](https://git.***REMOVED***/OpsRepos/k8s-reaper).

Kubernetes manifests can be in subdirectories of any depth in the
`kubernetes/` directory for organization purposes.

## ERB variables

The ERB templates are rendered using context variables from your project's
deploy.yml and are available in ERB in the `config` variable, for example in
`<%= config['environment'] %>`.

By default, the following context variables are available.

```
config['username']                  # your username
config['tag']                       # the git tag
config['cloud']                     # the Kubernetes cluster's cloud e.g. colo, aws, local (minikube), gcp
config['target']                    # the Kubernetes cluster target name e.g. colo-service, us-east-1, eu-west-1
config['kubernetes_major_version']  # the Kubernetes cluster's major version e.g. 1
config['kubernetes_minor_version']  # the Kubernetes cluster's major version e.g. 7
config['image_registry']            # the Kubernetes cluster's Docker image registry e.g. AWS ECR, GCP GCR, "local-registry" (none)
config['image_tag']                 # Docker tag used for all images
config['pull_policy']               # the default image pull policy for Kubernetes container templates
```

Extra flags can be provided by configuring your deploy.yml's `extra_flags`.

```
deploy:
  clusters:
    - target: local
      environment: staging
      extra_flags:
        cloud_fs: /etc/data/
        image_tag: latest
    - target: colo-service
      environment: prod
      extra_flags:
        cloud_fs: s3://
  flavors:
    default: {}
```

As you can see above with `image_tag`, the default variables above can be
overriden. See [examples/projects/deploy.yml](../examples/project/deploy.yml).

