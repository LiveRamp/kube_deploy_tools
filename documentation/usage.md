Below are descriptions and examples of KDT commands, their configurations in
`deploy.yaml`, and their CLI flags.

All KDT commands are intended to be used together, so configuration in
`deploy.yaml` is commonly used for more than one command.

<!-- TOC -->

- [`kdt push`](#kdt-push)
  - [Usage](#usage)
  - [Configuration](#configuration)
    - [Example](#example)
    - [Fields](#fields)
    - [CLI Flags](#cli-flags)
- [`kdt generate`](#kdt-generate)
  - [Usage](#usage-1)
  - [Configuration](#configuration-1)
    - [Example](#example-1)
    - [Fields](#fields-1)
    - [CLI Flags](#cli-flags-1)
- [`kdt publish`](#kdt-publish)
  - [Usage](#usage-2)
    - [Fields](#fields-2)
    - [CLI Flags](#cli-flags-2)
- [`kdt deploy`](#kdt-deploy)
  - [Usage](#usage-3)
  - [Configuration](#configuration-2)
    - [CLI Flags](#cli-flags-3)

<!-- /TOC -->

# `kdt push`

`kdt push` replaces `docker push` and is intended to be used after
`docker build` and `docker tag` to push your Docker image(s) to the
configured image registries in your `deploy.yaml`.

## Usage

```bash
# Push your image to all image registries in your deploy.yaml
bundle exec kdt push my-app

# Push your image to the specified image registry in your deploy.yaml
bundle exec kdt push my-app --registry=my-registry
```

## Configuration

### Example

```yaml
image_registries:
  - name: aws
    driver: aws
    prefix: 1234.dkr.ecr.us-west-2.amazonaws.com
    config:
      region: us-west-2
  - name: gcp
    driver: gcp
    prefix: gcr.io/my-project
  - name: local
    driver: noop
    prefix: local-registry
```

### Fields

* `.image_registries[].name` is the shorthand name of your image registry
  configuration
* `.image_registries[].driver` is the name of the supported image registry
  driver. The currently supported drivers are `aws`, `gcp`, `artifactory`, and `noop`.
* `.image_registries[].prefix` is the prefix of your image registry, and is
  available in ERB templates as the ERB variable `config["image_registry"]`:

  ```erb
  # Pod spec
  ...
        containers:
          - image: <%= config["image_registry"] %>/fluentd:<%= config["image_tag"] %>
  ```

### CLI Flags

TODO

# `kdt generate`

`kdt generate` reads all .yaml and .yaml.erb files in `kubernetes/` and
templates them out into the `build/kubernetes/` directory.

All Kubernetes manifests in `kubernetes/` are templated once for each
configured artifact.

## Usage

```bash
# By default, reads your deploy.yaml and `kubernetes/` directory to output
# Kubernetes manifests to the `build/kubernetes/` directory
bundle exec kdt generate
```

The ERB templates in your `kubernetes/` directory are rendered using
key-values from your project's deploy.yaml and are available
in ERB in the `config` hash variable as in the example below:

```erb
# Pod spec
...
      containers:
        - image: <%= config["image_registry"] %>/fluentd:<%= config["image_tag"] %>
          imagePullPolicy: <%= config["pull_policy"] %>
```

ERB hash values must be provided by configuring key-values in your deploy.yml's
`.artifacts[].flags`.

The following ERB hash values are set and available by default:
* `config['tag']` is the git tag
* `config['image_tag']` is the Docker tag used for all images, consisting of the
  git tag and Jenkins build ID

The `config['image_tag']` is the same image tag used to tag and push
Docker images in `bundle exec kdt push`, so it's important to use this variable
in your Pod specs.

For local stacks, we recommend overriding the default image tag
by setting `image_tag: latest` in your `deploy.yaml` for convenient local
iteration.

## Configuration

### Example

```yaml
default_flags:
  pull_policy: IfNotPresent
artifacts:
  - name: local
    image_registry: local
    flags:
      cloud: local
      pull_policy: Always
      # Recommended override for the default image_tag variable
      image_tag: latest
      my_app_data_location: /etc/data/
  - name: my-prod-artifact
    image_registry: gcp
    flags:
      cloud: gcp
      environment: prod
      my_app_data_location: s3://my-app-data/
    include_dir:
      - nginx/
flavors:
  default: {}
```

### Fields

* `.default_flags` is a map of key-values available as ERB hash values available
  for all manifests in each generated artifact. These are default key-values
  that are merged with `.artifacts[].flags`. These defaults are
  overrideable and the artifact flags take always precedence over the defaults.
* `.artifacts[].name` is the name of your artifact configuration
* `.artifacts[].image_registry` is the name of an image registry in
  `.image_registries`. The `.image_registriy[#{name}].prefix` is interpolated
  as the ERB hash value `config['image_registry']`.
* `.artifacts[].flags` is a map of key-values available as ERB hash values available
  for all manifests in the specified artifact. These override any key-values
  merged from `.default_flags`.
* `.artifacts[].include_dir` is an optional field to only

### CLI Flags

TODO

# `kdt publish`

`kdt publish` puts generated Kubernetes manifests from your `build/kubernetes/`
directory to the artifact server. Kubernetes manifests are bundled per artifact.

## Usage

```bash
bundle exec kdt publish
```

### Fields

TODO

### CLI Flags

# `kdt deploy`

## Usage

```bash
# Deploy the latest version of a project
bundle exec kdt deploy \
  --project=<Jenkins Job name> \
  --build=latest \
  --artifact=my-prod-artifact \
  --context=<my Kubernetes context for production>
```

## Configuration

### CLI Flags

TODO
