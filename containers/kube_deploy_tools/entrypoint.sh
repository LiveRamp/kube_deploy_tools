#!/bin/bash
# Example usage:
#   docker run \
#     -e LOCAL_UID=$UID \
#     -v $(pwd):/app \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     local-registry/kube_deploy_tools "kdt render_deploys"

set -e

# Use a local user to properly share volume mounts.
# Add local user, using LOCAL_UID passed in at runtime or fallback.
LOCAL_UID=${LOCAL_UID:-9001}
adduser -u $LOCAL_UID -s /bin/bash -D user
# Allow local user to create directories under /app.
chown --quiet user /app
# Allow local user to share docker daemon socket
addgroup user docker

# Authenticate to gcloud as local user
if [[ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]]; then
  echo "WARNING: no Google Credentials set, gcloud commands might fail"
else
  su user -c "gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}"
fi

exec su-exec user "$@"
