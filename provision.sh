#!/bin/bash

# Arguments
MYSQL_PASSWORD=${1}
SERVER_NAME=${2}
SERVER_ADMIN=${3}
ADMIN_USER=${4}
ADMIN_PASSWORD=${5}

# Basics
apt-get -y -q update
apt-get -y -q upgrade
apt-get -y -q install build-essential

## Add PHP repository
add-apt-repository ppa:ondrej/php
apt-get -y -q update

## Install packages
### Supresses password prompt
echo mysql-server-5.6 mysql-server/root_password password $MYSQL_PASSWORD | debconf-set-selections
echo mysql-server-5.6 mysql-server/root_password_again password $MYSQL_PASSWORD | debconf-set-selections
apt-get -y -q install git unzip mysql-server-5.6 apache2 memcached php7.0 php7.0-gd php7.0-imagick php7.0-json php7.0-mysql php7.0-curl php7.0-mcrypt php7.0-mbstring php7.0-tokenizer php7.0-xml php7.0-intl php7.0-zip php7.0-apcu php7.0-memcached

# Install application
cd /var/www
curl -O https://download.nextcloud.com/server/releases/latest.zip
unzip latest.zip
chown -R www-data:www-data /var/www/nextcloud/

# Setup webserver
echo '
<VirtualHost *:80>
<IfModule mod_rewrite.c>
  RewriteEngine On

  # Force to SSL
  RewriteCond %{HTTPS} off
  RewriteRule ^(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]
</IfModule>
</VirtualHost>
<VirtualHost *:443>
<IfModule mod_ssl.c>
  # General
  ServerName '$SERVER_NAME'
  ServerAlias www.'$SERVER_NAME'
  ServerAdmin '$SERVER_ADMIN'

  SSLEngine on
  SSLCertificateFile      /etc/ssl/certs/apache-selfsigned.crt
  SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key

  # Site
  DocumentRoot /var/www/nextcloud
  <Directory "/var/www/nextcloud">
    Require all granted
    Options +FollowSymlinks
    AllowOverride All

    <IfModule mod_dav.c>
      Dav off
    </IfModule>

    <IfModule mod_headers.c>
      Header always set Strict-Transport-Security "max-age=63072000; includeSubdomains;"
    </IfModule>

    SetEnv HOME /var/www/nextcloud
    SetEnv HTTP_HOME /var/www/nextcloud
  </Directory>

  # Logs
  ErrorLog ${APACHE_LOG_DIR}/error.log
  CustomLog ${APACHE_LOG_DIR}/access.log combined
</IfModule>
</VirtualHost>
' > /etc/apache2/sites-available/000-default.conf
sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=CO/ST=STATE/L=LOCATION/O=ORGANIZATION/CN=$SERVER_NAME"server -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt

a2enmod ssl
a2enmod rewrite
a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime
a2dissite default-ssl

sed -i 's/^\(;\)\(date\.timezone\s*=\).*$/\2 \"Europe\/Berlin\"/' /etc/php/7.0/apache2/php.ini
sed -i 's/^\(display_errors\s*=\).*$/\1 On/' /etc/php/7.0/apache2/php.ini

## Enable Opcache
sed -i 's/^\(;\)\(opcache\.validate_timestamps\s*=\).*$/\20/' /etc/php/7.0/apache2/php.ini
sed -i 's/^\(;\)\(opcache\.enable\s*=\).*$/\21/' /etc/php/7.0/apache2/php.ini
sed -i 's/^\(;\)\(opcache\.enable_cli\s*=\).*$/\21/' /etc/php/7.0/apache2/php.ini
sed -i 's/^\(;\)\(opcache\.interned_strings_buffer\s*=\).*$/\28/' /etc/php/7.0/apache2/php.ini
sed -i 's/^\(;\)\(opcache\.memory_consumption\s*=\).*$/\2128/' /etc/php/7.0/apache2/php.ini
sed -i 's/^\(;\)\(opcache\.max_accelerated_files\s*=\).*$/\210000/' /etc/php/7.0/apache2/php.ini
sed -i 's/^\(;\)\(opcache\.save_comments\s*=\).*$/\21/' /etc/php/7.0/apache2/php.ini
sed -i 's/^\(;\)\(opcache\.revalidate_freq\s*=\).*$/\21/' /etc/php/7.0/apache2/php.ini

# Clean up virtual hosts
rm /etc/apache2/sites-available/default-ssl.conf

service apache2 restart

# Setup database
## Basic
sed -i 's/^\(max_allowed_packet\s*=\s*\).*$/\1128M/' /etc/mysql/my.cnf
sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf

echo '[client]
user = root
password = '$MYSQL_PASSWORD'

[mysqladmin]
user = root
password = '$MYSQL_PASSWORD > /home/vagrant/.my.cnf
cp /home/vagrant/.my.cnf /root/.my.cnf

service mysql restart

## Nextcloud
echo "CREATE DATABASE nextcloud;" | mysql -uroot
echo "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" | mysql -uroot

# Configure Nextcloud
## Install application
sudo -u www-data /usr/bin/php /var/www/nextcloud/occ maintenance:install --database=mysql --database-name=nextcloud --database-user=nextcloud --database-pass=$MYSQL_PASSWORD --admin-user=$ADMIN_USER --admin-pass=$ADMIN_PASSWORD

## Tweak config
sed -i '$i\ \ '\''memcache.local'\'' => '\''\\OC\\Memcache\\APCu'\'',' /var/www/nextcloud/config/config.php
sed -i '$i\ \ '\''memcache.distributed'\'' => '\''\\OC\\Memcache\\Memcached'\'',' /var/www/nextcloud/config/config.php
sed -i '$i\ \ '\''memcached_servers'\'' => array\(array\('\''localhost'\'', 11211\),\),' /var/www/nextcloud/config/config.php
sudo -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set trusted_domains 1 --value=$SERVER_NAME
sudo -u www-data /usr/bin/php /var/www/nextcloud/occ background:cron

## Add cronjob
echo '
# nextcloud
*/15  *  *  *  * /usr/bin/php -f /var/www/nextcloud/cron.php' > /var/spool/cron/crontabs/www-data
