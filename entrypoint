#!/bin/bash
# Example usage:
#   docker run \
#     -v $(pwd):/app \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     local-registry/kube_deploy_tools "kdt render_deploys"

set -e

LOCAL_UID=$(stat -c '%u' /app)
if [ ${LOCAL_UID} != 0 ]; then
  # Use a local user to properly share volume mounts under /app.
  adduser -u ${LOCAL_UID} -s /bin/bash -D kdt
  # Allow local user to create directories under /app.
  chown --quiet kdt /app

  # Allow local user to share docker daemon socket.
  DOCKER_HOST="/var/run/docker.sock"
  if [[ -S ${DOCKER_HOST} ]]; then
    DOCKER_GID=$(stat -c '%g' ${DOCKER_HOST})
    if ! getent group "${DOCKER_GID}" >/dev/null; then
      # The gid is not used, so create a new group called 'docker'
      DOCKER_GROUP_NAME=docker
      addgroup -g "${DOCKER_GID}" "${DOCKER_GROUP_NAME}"
    else
      # The gid is used, so use the existing one
      # This is mainly because addgroup doesn't support looking up by gid. Grr.
      DOCKER_GROUP_NAME=$(getent group "${DOCKER_GID}" | cut -d: -f1)
    fi
    addgroup kdt "${DOCKER_GROUP_NAME}"
  fi

  drop_privileges_command='su-exec kdt'
fi

# If set, symlink kubectl version based on environment variable
if [[ -n "$KUBECTL_VERSION" ]]; then
  if ! [ -e /usr/local/bin/kubernetes/versions/${KUBECTL_VERSION}/kubectl ]; then
    echo -e "Environment variable, KUBECTL_VERSION, specifed an unsupported kubectl version: ${KUBECTL_VERSION}\n\nSupported versions:"
    ls /usr/local/bin/kubernetes/versions/ | sort -t. -k 2n,2 -k 3n,3
    exit 1
  fi
  ln -sf /usr/local/bin/kubernetes/versions/${KUBECTL_VERSION}/kubectl /usr/local/bin/kubectl
fi

# Authenticate to gcloud as local user
if [[ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
  echo "WARNING: no Google Credentials set, gcloud commands might fail"
else
  $drop_privileges_command gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}
fi

exec $drop_privileges_command "$@"
