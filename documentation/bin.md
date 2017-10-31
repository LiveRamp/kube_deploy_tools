# bin

The binaries in the `bin/` directory and described below can be invoked with
`bundle exec`:
```bash
bundle exec render_deploys --help
```

## templater
Allows smooshing a template ERB file with a context defined in YAML.

## render_deploys
Goes through the deploy.yml of a project and generates templating contexts for
tools like templater, for every cluster / flavor permutation in that file.
Calls `render_deploys_hook` (or a user specified hook) with this templating
context and a directory to output any rendered files to. Tars up each output
directory with the full parameters of the cluster / flavor / project / build
information for uploading to Artifactory.

## render_deploys_hook
Takes in a templating context and a target directory. Scans the kubernetes/ dir
recursively for .yaml and .yaml.erb files. Renders everything with a templating
context into the target directory, preserving directory hierarchy underneath
kubernetes/.

## deploy
Deploys published release artifacts from Jenkins by `kubectl apply`ing the
entire artifact.

