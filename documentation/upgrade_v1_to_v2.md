
# Upgrade KDT Config v1 to v2

To upgrade from KDT config v1 to v2, update your Gemfile to
source v2 of KDT.

```
source 'https://***REMOVED***'

group :kdt do
  gem 'kube_deploy_tools', '~> 2'
end
```

Then, run the upgrade:

```
bundle install
bundle exec kdt upgrade
```
