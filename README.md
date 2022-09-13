[![Gem Version](https://badge.fury.io/rb/kube_deploy_tools.svg)](https://badge.fury.io/rb/kube_deploy_tools)


### Table of Contents
- [Introduction - KDT](#kube_deploy_tools-kdt)
- [Getting Started](#getting-started)
    - [Install](#install)
    - [Configure](#configure)
    - [Usage](#configure)
        - [Parallel Generate/Publish](#parallel-generatepublish)
- [FAQ](#faq)
- [Changelog](#changelog)
- [Contribute](#contribute)

---

# kube_deploy_tools (kdt)

`kube_deploy_tools` (kdt) is a tool to simplify kubernetes manifest generation
and deployment. 
kdt is written in Ruby, but can be used with any project that deploys to Kubernetes. 
It can be seen as a lightweight alternative to more popular products like [Helm].
 
KDT is able to:

* ***generate***: Kubernetes manifests from flexible [ERB] templates.
  - Templating contexts have access to a `config` Hash of options.
  - Multiple versions of the same manifests can be defined by creating separate *artifacts* and *flavors* which modify `config`.

* ***push***: Docker images tagged with the prefix `local-registry/` to your configured image registry/ies. 
    kdt will re-tag images appropriately for the destination and push in parallel.

* ***publish***: a manifest of all generated manifests, docker images and tags for archival and eventual expiration 
    of all artifacts related to a single build. 
    - Options available to build in parallel. See below:.

* ***deploy*** manifests referencing your built and pushed images out to production.

Each of the use cases described above is defined as a separate subcommand of the parent `kdt` command. The tools are 
singularly configured by a `deploy.yaml` document checked-in to the root of your repository. While all of these 
components are used today at [@LiveRamp](https://github.com/LiveRamp) for a complete production lifecycle, they are also 
designed to be used individually.

# Getting Started

## Install

Include the `gem 'kube_deploy_tools', '~> 3'` in your project via a Gemfile or gemspec.

## Configure

Once kdt is installed, you will need to configure it. This is done by adding a new file named `deploy.yaml` at the 
root of your project. A minimal `deploy.yaml` for deploying to [Google Container Registry] is shown below:

```yaml
version: 2                        # version of kdt to be used
default_flags:
  pull_policy: IfNotPresent       # define default k-v pairs to be made available in ERB's `config` to all artifacts and flavors
artifacts:                        # define groups of manifests as named artifacts for `kdt generate`
  - name: prod
    image_registry: gcp
    flags: {}                     # define extra k-v pairs for ERB `config` during `kdt generate` for a specific artifact
flavors:
  default:                        # define extra k-v pairs for ERB `config` during `kdt generate` for a specific flavor
    important_config: '42'        # appears in `config` for the prod/default flavor, but nowhere else
artifact_registries:              # define destination for `kdt publish`
image_registries:                 # define image registries for `kdt push`
  - name: gcp                     # `kdt push` will deploy to Google Container Registry
    driver: gcp
    prefix: gcr.io/my-gcr-project
```

You can check out a [complete description](schemas/v2.schema.json) of the `deploy.yaml` schema.

Next, create a `kubernetes/deployment.yaml.erb` file as follows:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-first-kdt-app
  labels:
    app: my-first-kdt-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: my-first-kdt-app
  template:
    metadata:
      labels:
        app: my-first-kdt-app
    spec:
      containers:
        - name: my-app
          image: <%= config['image_registry'] %>/my-app:<%= config['tag'] %>
          imagePullPolicy: <%= config['pull_policy'] %>
    env:
      - name: IMPORTANT_CONFIG
        value: <%= config['important_config'] %>
```

Observe the use of [ERB] tags to fill in various values from the `config` Hash. The `config` hash
is generated from a combination of artifact `flags`, `flavors`, `default_flags`, and the settings
from `image_registries`. `tag` is autogenerated from your Git SCM workspace.

Now, run `bundle exec kdt generate` and observe
`build/kubernetes/prod_default/deployment.yaml` is created with all template
variables filled in.

To explore further,
* Build a docker image tagged `local-registry/my-app`, then run `kdt push my-app`.
* Run `kdt deploy -f build/kubernetes/prod_default --context my-kube-context` to send your generated
  manifests to a Kubernetes API server.

## Usage

```bash
bundle install --with development

# Run tests
bundle exec rake test

# Exec a binary in bin/
bundle exec kdt generate

    # Additional options 
    bundle exec kdt generate -m <deploy_yaml_manifest_file> -i <tmp_input_directory> -o <tmp_directory> 

# Can be tested only via running Unit tests
bundle exec kdt publish

    # Publish with extra argument capable of parallel runs in Jenkins
    bundle exec kdt publish -o <tmp_directory>
```

### Parallel Generate/Publish in Jenkins Pipeline
**Note:** Most other KDT actions are able to run in parallel on Jenkins without extra configurations. 
But, the KDT `generate` & `publish` steps requires extra argument(s) to allow parallel generation & publishing of manifest files.
- **Reason:**: Natively, the kdt generate & publish steps uses the same tmp directory. So, when using command 
the commands `kdt generate` and `kdt publish` in Jenkins parallel steps, a manifests generated in one step 
could be overwritten by another parallel step.

Following steps can be added in the jenkins pipeline for parallel generation/ publishing the manifest files.
```bash
String uniqOutputPath = "build/kubernetes/${BRANCH_NAME}/build/${BUILD_ID}/${env}/${app}/"
bundle exec kdt generate -i kubernetes/${env}/${app} -o ${uniqOutputPath}
bundle exec kdt publish -o ${uniqOutputPath}
```

## FAQ

***Q***: Will KDT help me build my Docker images?
* No. The recommended usage is to build your docker images ahead of time and pre-tag them as local-registry/name-here.
Then running `kdt push name-here` will automatically retag your images with your target registry and send them off.
---

### Changelog

For breaking changes, new features, and new fixes, see
[CHANGELOG.md](CHANGELOG.md).


### Contribute
We accept [pull requests]. They will be reviewed by a member of the LiveRamp development team as soon as possible.
Once the PR is merged, GitHub will auto-draft the release. Be sure to
add the same version as a tag (vX.Y.Z) and then publish it.
[GitHub Workflow] will then publish the gems.

[GitHub Workflow]: https://github.com/LiveRamp/kube_deploy_tools/blob/master/.github/workflows/release.yml
[pull requests]: https://github.com/LiveRamp/kube_deploy_tools/pulls


[Helm]: https://helm.sh
[ERB]: https://ruby-doc.org/stdlib-2.7.1/libdoc/erb/rdoc/ERB.html
