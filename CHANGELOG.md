
# Changelog

## 2.0.x

### Breaking Changes
* kdt will now only surface the `kdt` binary as a singular entrypoint. This means
that if you were previously invoking the kdt subcommands directly (eg.
`bundle exec publish_container` or
`bundle binstub kube_deploy_tools && bin/render_deploys`) then you will be
unable to invoke the binaries.

The fix is to modify your build script to execute commands through the kdt
entrypoint. For instance:

```bash
bundle exec publish_artifacts

# becomes

bundle exec kdt publish_artifacts
```

Please search for invocations of the following binaries and update them to use
the kdt entrypoint:

```
deploy
make_configmap
publish_artifacts
publish_container
render_deploys
render_deploys_hook
sweeper
templater
toolbox
```

## 1.4.x

### Breaking Changes
kdt will now default to an image pull policy of  `IfNotPresent`,changed from `Always`.

Any yaml templates using `imagePullPolicy: <%= config["pull_policy"] %>` will now default to not pulling an image tag if that tag is already on the node.
* If you have always used kdt to template out the image tag of your containers, this change does not affect you.
* However, if you have been using a static image tag that you keep replacing and rely on `imagePullPolicy: Always` to update that tag on nodes, then you will have to set that explicitly in your kubernetes yamls

## 1.3.x

### Breaking Changes
Support for the Jenkins Generic Artifactory Integration is removed and
artifactory.json is no longer generated.

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
* ERB trim mode is now enabled (`<% "ruby code" -%>` no longer leaves a newline when rendered)

### New Fixes
* `render_deploys` and `publish_container` can be called in any order in
a project's Jenkins build script because `render_deploys` no longer does
`rm -rf build/kubernetes/` to clean the entire directory and remove
the `images.yaml` artifact created by `publish_container`

