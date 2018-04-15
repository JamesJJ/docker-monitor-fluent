FROM alpine:3.6


RUN \
  apk update && \
  apk add \
    ca-certificates \
    ruby \
    ruby-irb \
    ruby-dev \
    ruby-bundler \
    ruby-json \
    git \
    build-base

RUN \
  mkdir /home/app_daemon \
  && adduser -h /home/app_daemon -s /sbin/nologin -D -g app_daemon app_daemon \
  && chown -R app_daemon:app_daemon /home/app_daemon


WORKDIR /opt/docker-monitor-fluent

ADD Gemfile ./
ADD *.rb ./

RUN \
  bundle install --no-color --verbose

RUN \
  apk del build-base git && \
  rm -f /var/cache/apk/APKINDEX.*.gz

RUN \
  chown app_daemon:app_daemon /opt/docker-monitor-fluent/*.rb \
  && chmod a-w /opt/docker-monitor-fluent/*.rb

# Usually reliably reading the docker socket, needs root (or docker group)
# USER app_daemon
USER root

ARG APP_CONFIG_VERSION
ENV APP_CONFIG_VERSION ${APP_CONFIG_VERSION:-unknown}

CMD [ "/usr/bin/ruby", "--", "./docker-monitor-fluent.rb" ]

