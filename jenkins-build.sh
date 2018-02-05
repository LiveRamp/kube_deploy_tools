#!/bin/bash
set -euo pipefail

bundle install --with development --path=vendor/bundle
bundle exec rake

# HACK(joshk): work around docker2 slaves not having dummy .gem/credentials
# file Can be removed when these commands are added to the VM template
# generation stage.
mkdir -p ~/.gem
cat >~/.gem/credentials <<EOF
---
:rubygems_api_key: 'missing'
EOF
chmod 0600 ~/.gem/credentials

case "$GIT_BRANCH" in
*/master)
  # Publish versioned gem
  bundle exec rake push
  ;;
esac

# Publish versioned image
bundle exec rake container_publish

# Build a docker container for images-sweeper
bundle exec rake container:kube_deploy_tools
bundle exec rake container_push:kube_deploy_tools
bundle exec kdt render_deploys
