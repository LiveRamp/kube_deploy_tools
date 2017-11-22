# kube_deploy_tools

LiveRamp Kubernetes build and release tools for:
- tagging and publishing Docker images to our image registry;
- rendering Kubernetes manifests with ERB;
- publishing Kubernetes manifests in a deploy artifact to Artifactory;
- applying Kubernetes manifests to a cluster.

# Setup

To enable kube_deploy_tools in your project, see
[documentation/setup.md](documentation/setup.md).

# Usage

To use kube_deploy_tools in your project, see
[documentation/README.md](documentation).

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
bundle exec render_deploys
```

