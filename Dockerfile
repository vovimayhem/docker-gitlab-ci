FROM debian:jessie

################################################################################
# Add GitlabCi user:
RUN useradd --create-home --shell /bin/bash --comment 'GitLab CI' gitlab_ci

################################################################################
# 1: Install dependencies:
#  - curl & ca-certificates
#  - runtime & db client dependencies
#  - build & db client dev dependencies
RUN export DEBIAN_FRONTEND=noninteractive && \
apt-get update && \
apt-get install -y curl ca-certificates --no-install-recommends && \
curl -SL 'https://www.postgresql.org/media/keys/ACCC4CF8.asc' | apt-key add - && \
echo 'deb http://apt.postgresql.org/pub/repos/apt/ wheezy-pgdg main' > /etc/apt/sources.list.d/pgdg.list && \
mkdir -p /tmp/packages && \
curl -SL 'http://dev.mysql.com/get/mysql-apt-config_0.3.2-1debian7_all.deb' -o /tmp/packages/mysql-apt-config.deb && \
dpkg -i /tmp/packages/mysql-apt-config.deb && rm -rf /tmp/packages/mysql-apt-config.deb && \
apt-get update && \
apt-get install -y \
        libxml2 \
        libxslt1.1 \
        libcurl3 \
        libreadline6 \
        libc6 \
        libssl1.0.0 \
        libmysqlclient18 mysql-common \
        openssh-server \
        git \
        libyaml-0-2 \
        postfix \
        libpq5 \
        libicu52 \
        --no-install-recommends && \
apt-get install -y \
        autoconf \
        checkinstall \
        g++ \
        gcc \
        isomd5sum \
        libc6-dev \
        libcurl4-openssl-dev \
        libffi-dev\
        libgdbm-dev \
        libicu-dev \
        libmysqlclient-dev \
        libncurses5-dev \
        libpq-dev \
        libreadline6-dev \
        libreadline-dev \
        libssl-dev \
        libxml2-dev \
        libxslt-dev \
        libyaml-dev \
        make \
        patch \
        zlib1g-dev \
        --no-install-recommends && \
rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/pgdg.list

################################################################################
# 2: Install Ruby:

# Set required version
ENV RUBY_ENGINE ruby
ENV RUBY_VERSION 2.0.0-p598
ENV RUBY_ROOT /opt/rubies/$RUBY_ENGINE-$RUBY_VERSION

# TODO: Fetch from https://github.com/ruby/ruby/archive/vX_X_X_X.tar.gz, as I
# don't like downloading from an unsecure URL.
# Build:
RUN echo 'gem: --no-rdoc --no-ri' >> /etc/gemrc && \
export RUBY_MAJOR=`echo $RUBY_VERSION | cut -d'.' -f 1,2` && \
export RUBY_SOURCE_DIR=/tmp/src/$RUBY_ENGINE-$RUBY_VERSION && \
export RUBY_SOURCE_URL="http://cache.ruby-lang.org/pub/ruby/$RUBY_MAJOR/ruby-$RUBY_VERSION.tar.bz2" && \
mkdir -p $RUBY_SOURCE_DIR && \
curl -SL $RUBY_SOURCE_URL | tar -xjC $RUBY_SOURCE_DIR --strip-components=1 && \
cd $RUBY_SOURCE_DIR && \
autoconf && \
./configure --prefix="$RUBY_ROOT" --enable-shared --disable-install-doc \
                                  --sysconfdir=/etc CFLAGS="-O3" && \
make -j"$(nproc)" && \
make install && \
export PATH=$RUBY_ROOT/bin:$PATH && \
gem install bundler

ENV PATH $RUBY_ROOT/bin:$PATH

################################################################################

# Continue as Gitlab CI user:
USER gitlab_ci


ENV GITLAB_CI_SOURCE_DIR /home/gitlab_ci/gitlab-ci
ENV GEM_HOME $GITLAB_CI_SOURCE_DIR/vendor/bundle
ENV PATH $GEM_HOME/bin:$PATH

################################################################################
# 3: Fetch gitlab-ci code:

ENV GITLAB_CI_VERSION 5.3.0
ENV GITLAB_CI_SOURCE_URL https://gitlab.com/gitlab-org/gitlab-ci/repository/archive.tar.bz2?ref=v$GITLAB_CI_VERSION
RUN mkdir -p $GITLAB_CI_SOURCE_DIR && \
curl -SL $GITLAB_CI_SOURCE_URL | tar -xjC $GITLAB_CI_SOURCE_DIR --strip-components=1 && \
cd $GITLAB_CI_SOURCE_DIR && \
echo "gem 'rails_stdout_logging'" >> Gemfile && \
bundle install --without development && \
rm -rf config/database.* && \
mv config/application.yml.example config/application.yml && \
mv config/unicorn.rb.example config/unicorn.rb && \
rm -r config/*.example* config/initializers/3_sidekiq.rb  config/unicorn.rb && \
mkdir -p $GEM_HOME && \
bundle config --global path "$GEM_HOME" && \
bundle config --global bin "$GEM_HOME/bin" && \
bundle install --without development test

ADD config/database.yml             $GITLAB_CI_SOURCE_DIR/config/database.yml
ADD config/initializers/sidekiq.rb  $GITLAB_CI_SOURCE_DIR/config/initializers/3_sidekiq.rb
ADD config/unicorn.rb               $GITLAB_CI_SOURCE_DIR/config/unicorn.rb

WORKDIR $GITLAB_CI_SOURCE_DIR

USER root

RUN chown -R gitlab_ci:gitlab_ci config/

################################################################################
# 4: Remove build dependencies:
RUN apt-get purge --auto-remove -y \
      autoconf \
      checkinstall \
      g++ \
      gcc \
      isomd5sum \
      libc6-dev \
      libcurl4-openssl-dev \
      libffi-dev\
      libgdbm-dev \
      libicu-dev \
      libmysqlclient-dev \
      libncurses5-dev \
      libpq-dev \
      libreadline6-dev \
      libreadline-dev \
      libssl-dev \
      libxml2-dev \
      libxslt-dev \
      libyaml-dev \
      make \
      patch \
      zlib1g-dev

################################################################################
# 5: Final Setup

USER gitlab_ci

RUN mkdir -p tmp/sockets/ \
    && chmod -R u+rwX  tmp/sockets/ \
    && mkdir -p tmp/pids/ \
    && chmod u+rwX  tmp/pids/

ENV RAILS_ENV production
ENV PORT 5000

CMD ["unicorn", "-p", "5000", "-c", "./config/unicorn.rb"]
