FROM centos:centos7

MAINTAINER Mateus Caruccio <mateus.caruccio@getupcloud.com>

ENV HOME=/opt/app-root/src \
  PATH=/opt/app-root/src/bin:/opt/app-root/bin:$PATH \
  RUBY_VERSION=2.0 \
  FLUENTD_VERSION=0.12.31 \
  GEM_HOME=/opt/app-root/src

LABEL io.k8s.description="Fluentd container for collecting of docker container logs" \
  io.k8s.display-name="Fluentd ${FLUENTD_VERSION}" \
  io.k8s.tags="logging,fluentd,mongodb"

# activesupport version 5.x requires ruby 2.2
# iproute needed for ip command to get ip addresses
RUN rpmkeys --import file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 && \
    yum install -y --setopt=tsflags=nodocs \
      gcc-c++ \
      ruby \
      ruby-devel \
      libcurl-devel \
      make \
      iproute && \
    yum clean all

RUN mkdir -p ${HOME} && \
    gem install -N --conservative --minimal-deps \
      fluentd:${FLUENTD_VERSION} \
      'activesupport:<5' \
      fluent-plugin-kubernetes_metadata_filter \
      'fluent-plugin-systemd:<0.1.0' \
      systemd-journal \
      fluent-plugin-rewrite-tag-filter \
      fluent-plugin-secure-forward \
      fluent-plugin-mongo

ADD configs.d/ /etc/fluent/configs.d/
ADD run.sh generate_throttle_configs.rb ${HOME}/

RUN mkdir -p /etc/fluent/configs.d/{dynamic,user} && \
    chmod 777 /etc/fluent/configs.d/dynamic && \
    ln -s /etc/fluent/configs.d/user/fluent.conf /etc/fluent/fluent.conf

WORKDIR ${HOME}
USER 0
CMD ["sh", "run.sh"]
