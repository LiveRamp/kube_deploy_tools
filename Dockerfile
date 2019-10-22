FROM ruby:2.6-alpine as build

WORKDIR /opt/kube_deploy_tools
COPY . /opt/kube_deploy_tools/

RUN apk add --no-cache git
RUN bundle install
RUN bundle exec rake

FROM ruby:2.6-alpine

RUN apk add --no-cache \
    bash \
    curl \
    git \
    python \
    su-exec \
    tar

# Install docker
# From https://github.com/docker-library/docker/blob/master/17.09/Dockerfile
ENV DOCKER_CHANNEL stable
ENV DOCKER_BUCKET download.docker.com
ENV DOCKER_VERSION 17.09.0-ce
ENV DOCKER_ARCH x86_64
ENV DOCKER_SHA256 a9e90a73c3cdfbf238f148e1ec0eaff5eb181f92f35bdd938fd7dab18e1c4647
RUN curl -fSL -o docker.tgz "https://${DOCKER_BUCKET}/linux/static/${DOCKER_CHANNEL}/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz" && \
  echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - && \
  tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/ && \
  rm docker.tgz && \
  dockerd -v && \
  docker -v

# Install awscli
RUN apk add --no-cache \
  --virtual .deps \
  py-pip && \
  pip install awscli && \
  aws --version && \
  apk del .deps

# Install gcloud
# From https://github.com/GoogleCloudPlatform/cloud-sdk-docker/blob/master/alpine/Dockerfile
ENV CLOUD_SDK_VERSION=233.0.0
ENV CLOUD_SDK_VERSION=$CLOUD_SDK_VERSION
ENV GOOGLE_SDK_LOCATION /opt
ENV PATH ${GOOGLE_SDK_LOCATION}/google-cloud-sdk/bin:${PATH}
RUN mkdir -p "${GOOGLE_SDK_LOCATION}" && \
  curl -fSL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${CLOUD_SDK_VERSION}-linux-x86_64.tar.gz | \
  tar -C "${GOOGLE_SDK_LOCATION}" -xzf - && \
  ln -s /lib /lib64 && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image && \
  gcloud --version

# Install kubectl
# From https://hub.docker.com/r/lachlanevenson/k8s-kubectl/ and
#      https://www.jeffgeerling.com/blog/2018/install-kubectl-your-docker-image-easy-way
ENV KUBECTL_LATEST_VERSION="v1.11.7"
RUN AVAILABLE_KUBECTL_VERSIONS="v1.7.2 v1.9.6 v1.10.12 ${KUBECTL_LATEST_VERSION}" && \
  install -d /usr/local/bin/kubernetes/versions -o root -g root -m 0755 && \
  for VERSION in ${AVAILABLE_KUBECTL_VERSIONS}; do \
    MAJOR_MINOR_VERSION=${VERSION%.*} && \
    install -d /usr/local/bin/kubernetes/versions/${MAJOR_MINOR_VERSION} -o root -g root -m 0755 && \
    curl -fSL -o /usr/local/bin/kubernetes/versions/${MAJOR_MINOR_VERSION}/kubectl \
      https://storage.googleapis.com/kubernetes-release/release/${VERSION}/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubernetes/versions/${MAJOR_MINOR_VERSION}/kubectl && \
    ln -s /usr/local/bin/kubernetes/versions/${MAJOR_MINOR_VERSION}/kubectl /usr/local/bin/kubectl${MAJOR_MINOR_VERSION}; \
  done && \
  ln -s /usr/local/bin/kubernetes/versions/${KUBECTL_LATEST_VERSION%.*}/kubectl /usr/local/bin/kubectl

# Install kube_deploy_tools
COPY --from=build /opt/kube_deploy_tools/*.gem /opt/kube_deploy_tools/install.gem
RUN gem install /opt/kube_deploy_tools/install.gem

WORKDIR /app

COPY entrypoint /opt/bin/entrypoint

ENTRYPOINT ["/opt/bin/entrypoint"]
