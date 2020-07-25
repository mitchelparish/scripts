#!/bin/bash

export NAME=""
export ENV="production"
export DOMAIN=""
export MYSQL_HOST='localhost'
export MYSQL_DATABASE=""
export MYSQL_USER=''
export MYSQL_PASSWORD=`date +%s | sha256sum | base64 | head -c 32`
export EMAIL=""

sudo add-apt-repository -y ppa:ondrej/php

sudo apt-get install -y \
  certbot \
  nginx \
  mysql-server \
  php7.4-fpm \
  php7.4-cli \
  php7.4-curl \
  php7.4-gd \
  php7.4-json \
  php7.4-mysql \
  php7.4-soap \
  php7.4-xml

mkdir ~/bin
curl https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar > ~/bin/wp
chmod +x ~/bin/wp
source ~/.profile

sudo mysql -e "create database ${MYSQL_DATABASE};"
sudo mysql -e "grant all on ${MYSQL_DATABASE}.* to '${MYSQL_USER}'@'${MYSQL_HOST}' identified by '${MYSQL_PASSWORD}';"

cd /var/www/html
sudo chown -R ubuntu:ubuntu .
rm *
wp core download
wp config create --dbname="${MYSQL_DATABASE}" --dbuser="${MYSQL_USER}" --dbpass="${MYSQL_PASSWORD}"

sudo service nginx stop
sudo certbot certonly -n -d ${DOMAIN} --standalone --agree-tos --email ${EMAIL}
echo "server {
  listen 443 ssl;
  listen [::]:443 ssl;
  root /var/www/html;
  index index.html index.php;
  server_name $DOMAIN;
  ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

  location / {
    try_files \$uri \$uri/ =404;
  }

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
  }
}

server {
  listen 80;
  listen [::]:80 default_server;
  server_name $DOMAIN;
  return 301 https://\$host\$request_uri;
}" | sudo tee /etc/nginx/sites-available/default
sudo service nginx start
