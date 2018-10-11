#!/bin/bash
set -euo pipefail

bundle install --with development --path=vendor/bundle
bundle exec rake

# Declarative pipeline sets $GIT_BRANCH to the short branch name. (e.g. master)
# Classic jobs set $GIT_BRANCH to the full ref (e.g. origin/master)
case "$GIT_BRANCH" in
*/master|master)
  # Publish versioned gem
  bundle exec rake push
  ;;
*/release-*|release-*)
  # Publish versioned gem
  bundle exec rake push
  ;;
*)
  echo "Not running a rake push step on $GIT_BRANCH"
;;
esac

# Generate K8s manifests for Sweeper
bundle exec kdt render_deploys
# Generate container image for Sweeper and push
bundle exec rake container:kube_deploy_tools
# Versioned image
bundle exec rake container_push:kube_deploy_tools
# Latest image
bundle exec rake container_publish
# Record keeping in Artifactory
bundle exec kdt publish_artifacts
