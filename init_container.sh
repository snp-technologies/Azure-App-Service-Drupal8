#!/bin/bash

# set -e

php -v
# setup server root
test ! -d "$HOME_SITE" && echo "INFO: $HOME_SITE not found. creating..." && mkdir -p "$HOME_SITE"
if [ ! $WEBSITES_ENABLE_APP_SERVICE_STORAGE ]; then
    echo "INFO: NOT in Azure, chown for "$HOME_SITE
    chown -R www-data:www-data $HOME_SITE
fi

# setup nginx log dir
# http://nginx.org/en/docs/ngx_core_module.html#error_log
# sed -i "s|error_log /var/log/error.log;|error_log stderr;|g" /etc/nginx/nginx.conf

echo "INFO: creating /run/php/php7.0-fpm.sock ..."
test -e /run/php/php7.0-fpm.sock && rm -f /run/php/php7.0-fpm.sock
mkdir -p /run/php
touch /run/php/php7.0-fpm.sock
chown www-data:www-data /run/php/php7.0-fpm.sock
chmod 777 /run/php/php7.0-fpm.sock
echo "Starting SSH ..."
service ssh start

echo "Starting php-fpm ..."
service php7.0-fpm start
chmod 777 /run/php/php7.0-fpm.sock

echo "Starting Nginx ..."
mkdir -p /home/LogFiles/nginx
if test ! -e /home/LogFiles/nginx/error.log; then
    touch /home/LogFiles/nginx/error.log
fi
/usr/sbin/nginx