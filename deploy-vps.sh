#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
web_root="/var/www/wavbits.com"
vhost_file="/etc/httpd/conf.d/wavbits.com.conf"

install -o root -g root -m 0644 "$project_dir/index.html" "$web_root/index.html"
install -o root -g root -m 0644 "$project_dir/style.css" "$web_root/style.css"

cat >"$vhost_file" <<'APACHE'
<VirtualHost *:80>
    ServerName wavbits.com
    DocumentRoot /var/www/wavbits.com

    <Directory /var/www/wavbits.com>
        Options FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    RewriteEngine On
    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [END,NE,R=permanent]

    ErrorLog logs/wavbits.com-error.log
    CustomLog logs/wavbits.com-access.log combined
</VirtualHost>
APACHE

apachectl configtest
systemctl reload httpd

