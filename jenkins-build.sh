#!/bin/bash
set -euo pipefail

bundle install --with development --path=vendor/bundle
bundle exec rake

case "$GIT_BRANCH" in
*/master) bundle exec rake push ;;
esac
