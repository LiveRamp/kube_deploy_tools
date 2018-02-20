
# Changelog

## 1.3.x

### Breaking Changes
Support for the Jenkins Generic Artifactory Integration is removed and
images.yaml is no longer generated.

Instead, a new command `publish_artifacts` will upload release artifacts
to Artifactory.

In your Jenkins build script, add `bundle exec kdt publish_artifacts`.

Please make the following changes in your Jenkins build.

* Under Build Environment, un-check Generic Artifactory Integration to disable.
* Under Bindings, add a username and password (separated) with
`ARTIFACTORY_USERNAME` as the Username Variable,
`ARTIFACTORY_PASSWORD` as the Password Variable, and
`jenkins_publisher/****** (***REMOVED***)` selected as the specific
credentials. See below.

![Jenkins Artifactory upload](documentation/jenkins_build.png)


### New Features
* The new command `publish_artifacts` uploads release artifacts to Artifactory

### New Fixes
* `render_deploys` and `publish_container` can be called in any order in
a project's Jenkins build script because `render_deploys` no longer does
`rm -rf build/kubernetes/` to clean the entire directory and remove
the `images.yaml` artifact created by `publish_container`

