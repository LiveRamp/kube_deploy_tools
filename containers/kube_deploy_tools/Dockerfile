FROM ruby:2.3-alpine as build

WORKDIR /opt/kube_deploy_tools
COPY Gemfile Rakefile kube_deploy_tools.gemspec README* LICENSE* clusters.yml /opt/kube_deploy_tools/
COPY bin /opt/kube_deploy_tools/bin
COPY lib /opt/kube_deploy_tools/lib

RUN bundle install && \
  bundle exec rake build

FROM ruby:2.3-alpine

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
ENV GOOGLE_SDK_LOCATION /opt
ENV PATH ${GOOGLE_SDK_LOCATION}/google-cloud-sdk/bin:${PATH}
RUN mkdir -p "${GOOGLE_SDK_LOCATION}" && \
  curl -fSL https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz | \
  tar -C "${GOOGLE_SDK_LOCATION}" -xzf - && \
  ln -s /lib /lib64 && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image && \
  gcloud --version

# Install kube_deploy_tools
COPY --from=build /opt/kube_deploy_tools/pkg /opt/kube_deploy_tools
RUN gem install /opt/kube_deploy_tools/*.gem

WORKDIR /app

COPY containers/kube_deploy_tools/entrypoint.sh /opt/bin/entrypoint.sh

ENTRYPOINT ["/opt/bin/entrypoint.sh"]
