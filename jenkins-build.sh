#!/bin/bash
set -euo pipefail

bundle install --with development

# Run default task i.e. rspec
bundle exec rake

# Strip 'origin/' prefix from current branch name.
GIT_BRANCH=${GIT_BRANCH#origin/}
case "$GIT_BRANCH" in
master)
    bundle exec rake update_gemfile_dot_lock

    bundle exec rake autopublish

    echo "Final commit hash: $GIT_COMMIT"
  ;;
esac
