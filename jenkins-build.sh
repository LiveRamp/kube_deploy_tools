#!/bin/bash
set -euo pipefail

bundle install --with development

# Run default task i.e. rspec
bundle exec rake

bundle exec rake update_gemfile_dot_lock_no_halt

bundle exec rake autopublish

echo "Final commit hash: $GIT_COMMIT"
