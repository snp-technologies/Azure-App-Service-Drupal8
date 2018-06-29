FROM nginx
MAINTAINER Azure App Service Container Images <appsvc-images@microsoft.com>

ARG GIT_TOKEN

# ========
# ENV vars
# ========

# ssh
ENV SSH_PASSWD "root:Docker!"
#nginx
ENV NGINX_LOG_DIR "/home/LogFiles/nginx"
#php
ENV PHP_HOME "/etc/php/7.0"
ENV PHP_CONF_DIR $PHP_HOME"/cli"
ENV PHP_CONF_FILE $PHP_CONF_DIR"/php.ini"
#Web Site Home
ENV HOME_SITE "/var/www/html/docroot"

#
ENV DOCKER_BUILD_HOME "/dockerbuild"

# ====================
# Download and Install
# ~. essentials
# 1. php7.0-common/php7.0-fpm/php-pear/php7.0-apcu
# 2. ssh
# 3. drush
# 4. composer
# ====================
COPY * /tmp/

    # -------------
    # ~. essentials
    # -------------

RUN set -ex \
        && essentials=" \
        ca-certificates \
        wget \
        " \
        && apt-get update \
        && apt-get install -y -V --no-install-recommends $essentials \
        && rm -r /var/lib/apt/lists/* \
        # ------------------
        # 1. php7.0-common/php7.0-fpm/php-pear/php7.0-apcu
        # ------------------
        && phps=" \
        php7.0-common \
        php7.0-fpm \
        php-pear \
        php7.0-apcu \
        php7.0-gd \
        php7.0-dba \
        php7.0-mysql \
        php7.0-xml \
        " \
        && apt-get update \
        && apt-get install -y -V --no-install-recommends $phps \
        && rm -r /var/lib/apt/lists/* \
        # ------
        # 2. ssh
        # ------
        && apt-get update \
        && apt-get install -y --no-install-recommends openssh-server \
        && echo "$SSH_PASSWD" | chpasswd
    
RUN apt-get install curl -y
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin
RUN ln -s /usr/local/bin/composer.phar /usr/local/bin/composer
RUN sed -i '84i export PATH="$HOME/.composer/vendor/bin:$PATH"' ~/.bashrc
        # ------
        # 
        # ------
        # 4. composer
        # ------
RUN apt-get install git  wget -y

###PHP dependencies for Composer###
RUN apt-get install curl -y
RUN apt-get autoremove -y
RUN apt-get install wget curl git -y
RUN apt-get update -y
RUN apt-get install php7.0-mbstring
RUN apt-get install php7.0-curl
RUN apt-get install php7.0-zip -y

### Begin Drush install ###
RUN wget https://github.com/drush-ops/drush/releases/download/8.1.13/drush.phar
RUN chmod +x drush.phar
RUN mv drush.phar /usr/local/bin/drush
RUN drush init -y
### END Drush install ###

WORKDIR /var/www/html
RUN git clone -b master https://$GIT_TOKEN@github.com/snp-technologies/zackcooper.git .

RUN php --ini
WORKDIR /var/www/html/docroot
RUN composer install
RUN composer global require drush/drush

# Add directories for public and private files
RUN mkdir -p  /home/site/wwwroot/sites/default/files \
    && mkdir -p  /home/site/wwwroot/sites/default/files/private \
    && ln -s /home/site/wwwroot/sites/default/files  /var/www/html/docroot/sites/default/files \
    && ln -s /home/site/wwwroot/sites/default/files/private /var/www/html/docroot/sites/default/files/private

# =========
# Configure
# =========

RUN set -ex\
        && rm -rf /var/log/nginx \
        && ln -s $NGINX_LOG_DIR /var/log/nginx

COPY sshd_config /etc/ssh/

# php
COPY php.ini /etc/php/7.0/cli/php.ini
COPY www.conf /etc/php/7.0/fpm/pool.d/www.conf
# nginx
COPY nginx.conf /etc/nginx/nginx.conf

COPY init_container.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init_container.sh
RUN chmod 777 /var/www/html/docroot/sites/default/settings.php
EXPOSE 2222 80
ENTRYPOINT ["init_container.sh"]