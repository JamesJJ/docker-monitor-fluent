FROM alpine:3.4

MAINTAINER JamesJJ@users.noreply.github.com

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
  bundle install --no-color --verbose && \
  gem install --no-document net_http_unix-0.2.1-timeout-deprecation.gem && \
  apk del build-base git && \
  rm -f /var/cache/apk/APKINDEX.*.gz

ADD *.rb ./

CMD [ "/usr/bin/ruby", "--", "./docker-monitor-fluent.rb" ]

