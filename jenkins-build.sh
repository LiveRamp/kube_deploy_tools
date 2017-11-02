#!/bin/bash
set -euo pipefail

bundle install --with development

# Run default task i.e. rspec
bundle exec rake

bundle exec rake autopublish

echo "Final commit hash: $GIT_COMMIT"
