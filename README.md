# kube_deploy_tools

kube_deploy_tools (kdt) is a tool to simplify kubernetes manifest generation
and deployment.

kdt is not specific to ruby projects; it can be used with any project that
deploys to kubernetes.   

# Getting Started

## Install
Start by adding a new `Gemfile` at the root of your project (or updating your existing `Gemfile`):

```ruby
source 'https://gemserver.***REMOVED***'

group :kdt do
  gem 'kube_deploy_tools', '~> 2'
end
```

and then installing with [bundler](https://bundler.io/):

```bash
bundle install
```

## Configure

Once kdt is installed, you will need to configure it. This is done by adding
a new file named `deploy.yaml` at the root of your project. A minimal
`deploy.yaml` is shown below:

```yaml
version: 2                        # version of kdt to be used
default_flags:
  pull_policy: IfNotPresent
artifacts:
  - name: prod
    image_registry: gcp
    flags:
      target: dist
      environment: prod
      cloud: gcp
image_registries:                 # define image registries used here
  - name: gcp                     # deploy to gcr
    driver: gcp
    prefix: ***REMOVED***
```

Now that kdt is installed and configured for your project, see how you can
add your kubernetes manifests in [documentation/setup.md](documentation/setup.md).

# Usage

To use kube_deploy_tools in your project, see
[documentation/usage.md](documentation/usage.md).

# Why KDT?

KDT is helpful for tying together the following steps in a deployment chain, as described below. Note that the bash and `kdt` commands are closer to *pseudocode* and provided as examples only.

| Step                                                                   | Goal                                                                                                                                               | Pseudo Command                                                                                                             | `kdt` Command                                                           |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| 1. tagging and publishing Docker images to our image registry          | to make the Docker image pullable from Kubernetes workers for running Pods                                                                         | `docker tag local-registry/my-app gcr.io/my-registry/my-app:$TAG && docker push gcr.io/my-registry/my-app:$TAG`            | `kdt push local-registry/my-app`                                        |
| 2. rendering Kubernetes manifests with ERB                             | to allow for parametrization of Kubernetes manifests per environment target, such as parametrizing the Docker image tag published in the last step | `for $file in kubernetes/; do sed -i 's/IMAGE_NAME/gcr.io\/my-registry\/my-app:$TAG' $file > build/kubernetes/$file; done` | `kdt generate`                                                          |
| 3. publishing Kubernetes manifests in a deploy artifact to Artifactory | to make release-ready Kubernetes manifests available at deploy time                                                                                | `gzip build/kubernetes $artifact && curl -X PUT my.artifactory.net/registry/artifact $artifact`                            | `kdt publish`                                                           |
| 4. applying Kubernetes manifests to a cluster                          | to provide release tooling best-practices at deploy time                                                                                           | `curl -X GET my.artifactory.net/registry/artifact \| gunzip \| kubectl apply -f -`                                           | `kdt deploy --artifact=my-artifact --build=latest --context=production` |


This deployment chain outputs release-ready artifacts, with appropriate tooling to configure and deploy these artifacts.

i.e.
```
(baked, tagged + published Docker images) +
(templated + rendered Kubernetes manifests)
=
your deployment
```

KDT will not:
- build, compile or package your app (e.g. `mvn install || npm install # etc`)
- build Docker images (e.g. `docker build -t local-registry/my-app .`)

Putting this all together, all of the above commands should be run in your deployment chain, as appropriate within your CI/CD setup:

```bash
mvn install || npm install
docker build -t ...

kdt push ...
kdt generate
kdt publish

kdt deploy ...
```

---
- [kube_deploy_tools](#kubedeploytools)
- [2.x NOTICE](#2x-notice)
- [Setup](#setup)
- [Usage](#usage)
- [Changes](#changes)
- [Contribute](#contribute)

# 2.x NOTICE
You're viewing docs for v2.x. To view docs for v1.x, please see:
https://git.***REMOVED***/OpsRepos/kube_deploy_tools/tree/release-1.x

# Changes

For breaking changes, new features, and new fixes, see
[CHANGELOG.md](CHANGELOG.md).

# Contribute

```bash
# Install ruby w/ Homebrew
brew install ruby

# Or install ruby w/ rbenv
brew install rbenv ruby-build
rbenv install 2.3.0
rbenv global 2.3.0

# Install gem
gem install bundler
```

```bash
bundle install --with development

# Run tests
bundle exec rake test

# Exec a binary in bin/
bundle exec kdt generate
```
