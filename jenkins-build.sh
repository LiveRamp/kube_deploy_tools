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
*/master) bundle exec rake push ;;
esac
