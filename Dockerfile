FROM alpine:latest

MAINTAINER JamesJJ@users.noreply.github.com

ARG APP_CONFIG_VERSION
ENV APP_CONFIG_VERSION ${APP_CONFIG_VERSION:-unknown}

WORKDIR /opt/docker-monitor-fluent
ADD Gemfile ./
ADD gems ./

RUN \
  apk update && \
  apk add \
    ca-certificates \
    ruby-dev \
    ruby-bundler \
    ruby-json \
    git \
    build-base && \
    adduser -h /opt -s /sbin/nologin -D -H -g app_daemon app_daemon && \
  bundle install --no-color --verbose && \
  gem install --no-document net_http_unix-0.2.1-timeout-deprecation.gem && \
  apk del build-base git && \
  rm -f /var/cache/apk/APKINDEX.*.gz

ADD *.rb ./

USER app_daemon

CMD [ "/usr/bin/ruby", "--", "./docker-monitor-fluent.rb" ]

