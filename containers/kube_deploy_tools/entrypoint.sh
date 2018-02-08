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
    addgroup -g ${DOCKER_GID} docker
    addgroup kdt docker
  fi

  drop_privileges_command='su-exec kdt'
fi

# Authenticate to gcloud as local user
if [[ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
  echo "WARNING: no Google Credentials set, gcloud commands might fail"
else
  $drop_privileges_command gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}
fi

exec $drop_privileges_command "$@"
