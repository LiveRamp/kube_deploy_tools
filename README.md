# kube_deploy_tools

What is kube_deploy_tools, aka KDT or kdt?

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

# Setup

To enable kube_deploy_tools in your project, see
[documentation/setup.md](documentation/setup.md).

# Usage

To use kube_deploy_tools in your project, see
[documentation/usage.md](documentation/usage.md).

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
