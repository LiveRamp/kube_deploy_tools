
# Basic Usage

## Template

### Rendering ERB templated Kubernetes manifests
To render Kubernetes manifest .yaml and .yaml.erb files from the `kubernetes/`
directory to the `build/kubernetes/` directory:

```bash
bundle exec kdt render_deploys
```

See [documentation/kube_manifests_with_erb.md](kube_manifests_with_erb.md)
for how to write Kubernetes manifests with ERB.

## Deploy

### Deploy a Jenkins build artifact to production or staging
To deploy Kubernetes manifests in a deploy artifact uploaded to Artifactory
by your Jenkins build, find the build name in Jenkins and specify the cluster
target and environment as specified in your deploy.yml:

```bash
bundle exec kdt deploy --target us-east-1 --environment staging --build 37
```

`deploy` will recursively `kubectl apply -f` Kubernetes manifests in this deploy
artifact.

### Deploy Kubernetes manifests to your local minikube context

To deploy Kubernetes manifests that you rendered locally in your
`build/kubernetes/` directory, use the `-f` flag:

```bash
bundle exec kdt deploy --target local --environment staging \
  -f build/kubernetes/local/staging/default/

# Or specify a context
bundle exec kdt deploy --context minikube -f build/kubernetes/local/staging/default/
```

### Deploy a specific file

As above, you can use `-f` to specify a file or more specific directory:

```bash
bundle exec kdt deploy --context minikube \
  -f build/kubernetes/local/staging/default/dep-nginx.yaml
```

### Deploying a flavor
TODO

### Workflows for local development
TODO

### Further docs
See [documentation/bin.md](bin.md) for descriptions about
executables available in `bin/`.

