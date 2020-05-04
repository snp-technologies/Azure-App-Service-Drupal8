# Source: https://github.com/docker-library/drupal/blob/189686e109917d7bffaf28024be7d6d28495f57d/8.8/apache/Dockerfile
# Guidance: https://www.drupal.org/docs/8/system-requirements/drupal-8-php-requirements
FROM php:7.3-apache-stretch

ARG GIT_TOKEN
ARG BRANCH
ARG GIT_REPO

COPY apache2.conf /bin/
COPY init_container.sh /bin/

###  Configure root user credentials ###
RUN chmod 755 /bin/init_container.sh \
    && echo "root:Docker!" | chpasswd \
    && echo "cd /home" >> /etc/bash.bashrc

# install the PHP extensions we need
RUN set -eux; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libpng-dev \
		libpq-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd \
		--with-freetype-dir=/usr \
		--with-jpeg-dir=/usr \
		--with-png-dir=/usr \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		gd \
		opcache \
		pdo_mysql \
		pdo_pgsql \
		zip \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# Additional libraries not in base recommendations
RUN apt-get update; \
	apt-get install -y --no-install-recommends \
        openssh-server \
        curl \
        git \
        mysql-client \
        nano \
        sudo \
        tcptraceroute \
        vim \
        wget \
        libssl-dev \
	;

# set php.ini file
RUN cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# set recommended PHP.ini settings
# Include PHP recommendations from https://www.drupal.org/docs/7/system-requirements/php
RUN { \
  echo 'error_log=/var/log/apache2/php-error.log'; \
  echo 'log_errors=On'; \
  echo 'display_errors=Off'; \
  } > /usr/local/etc/php/php.ini

# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

### Change apache logs directory for App Service support ###
RUN   \
   rm -f /var/log/apache2/* \
   && rmdir /var/lock/apache2 \
   && rmdir /var/run/apache2 \
   && rmdir /var/log/apache2 \
   && chmod 777 /var/log \
   && chmod 777 /var/run \
   && chmod 777 /var/lock \
   && chmod 777 /bin/init_container.sh \
   && cp /bin/apache2.conf /etc/apache2/apache2.conf \
   && rm -rf /var/www/html \
   && rm -rf /var/log/apache2 \
   && mkdir -p /home/LogFiles \
   && ln -s /home/site/wwwroot /var/www/html \
   && ln -s /home/LogFiles /var/log/apache2 

# Install memcached support for php
RUN apt-get update && apt-get install -y libmemcached-dev zlib1g-dev \
    && pecl install memcached-3.1.3 \
    && docker-php-ext-enable memcached
RUN apt-get update && apt-get install -y memcached

### Begin Drush install ###
RUN wget https://github.com/drush-ops/drush/releases/download/8.1.13/drush.phar
RUN chmod +x drush.phar
RUN mv drush.phar /usr/local/bin/drush
RUN drush init -y
### END Drush install ###

# =========
# App Service configurations
# Source https://github.com/Azure/app-service-builtin-images/blob/master/php/7.2.1-apache/Dockerfile
# =========

COPY sshd_config /etc/ssh/

EXPOSE 2222 80

ENV APACHE_RUN_USER www-data
ENV PHP_VERSION 7.3
ENV PORT 8080
ENV WEBSITE_ROLE_INSTANCE_ID localRoleInstance
ENV WEBSITE_INSTANCE_ID localInstance
ENV PATH ${PATH}:/home/site/wwwroot


WORKDIR /var/www/html
RUN git clone -b $BRANCH https://$GIT_TOKEN@github.com/$GIT_REPO.git .

# Add directories for public and private files
RUN mkdir -p  /home/site/wwwroot/sites/default/files \
    && mkdir -p  /home/site/wwwroot/sites/default/files/private \
    && ln -s /home/site/wwwroot/sites/default/files  /var/www/html/docroot/sites/default/files \
    && ln -s /home/site/wwwroot/sites/default/files/private /var/www/html/docroot/sites/default/files/private

### Webroot permissions per www.drupal.org/node/244924#linux-servers ###
WORKDIR /var/www/html/docroot
RUN chown -R root:www-data .
RUN find . -type d -exec chmod u=rwx,g=rx,o= '{}' \;
RUN find . -type f -exec chmod u=rw,g=r,o= '{}' \;
# For sites/default/files directory, permissions come from
# /home/site/wwwroot/sites/default/files

ENTRYPOINT ["/bin/init_container.sh"]