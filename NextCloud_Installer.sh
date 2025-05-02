#!/bin/bash

# MIT License
# 
# Copyright (c) RTDeveloperman Boosio(Boosyou) 2025 Developerman.it@gmail.com
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


set -e

# ====== Function to generate a random password ======
generate_password() {
  tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c 16
}

# ====== Default Values ======
DEFAULT_IP=$(hostname -I | awk '{print $1}')
DEFAULT_DB_NAME="nextcloud"
DEFAULT_DB_USER="nc_user"
DEFAULT_DB_PASS=$(generate_password)
DEFAULT_NC_USER="admin"
DEFAULT_NC_PASS=$(generate_password)
DEFAULT_PORT=80
INSTALL_DIR="/var/www/nextcloud"

echo "🔧 Starting Advanced Nextcloud installation..."

# ====== User Inputs with Defaults ======
read -p "Enter your domain or IP [${DEFAULT_IP}]: " DOMAIN
DOMAIN=${DOMAIN:-$DEFAULT_IP}

read -p "Enter database name [${DEFAULT_DB_NAME}]: " DB_NAME
DB_NAME=${DB_NAME:-$DEFAULT_DB_NAME}

read -p "Enter database username [${DEFAULT_DB_USER}]: " DB_USER
DB_USER=${DB_USER:-$DEFAULT_DB_USER}

read -s -p "Enter database password [auto-generated]: " DB_PASS
echo ""
DB_PASS=${DB_PASS:-$DEFAULT_DB_PASS}

read -p "Enter Nextcloud admin username [${DEFAULT_NC_USER}]: " NC_ADMIN
NC_ADMIN=${NC_ADMIN:-$DEFAULT_NC_USER}

read -s -p "Enter Nextcloud admin password [auto-generated]: " NC_PASS
echo ""
NC_PASS=${NC_PASS:-$DEFAULT_NC_PASS}

read -p "Enter HTTP port to use [${DEFAULT_PORT}]: " PORT
PORT=${PORT:-$DEFAULT_PORT}

# ====== Install Dependencies ======
echo "📦 Installing dependencies..."
apt update && apt install -y nginx mariadb-server redis-server \
    php php-cli php-fpm php-mysql php-xml php-gd php-curl php-zip \
    php-mbstring php-intl php-bcmath php-imagick php-redis php-ldap unzip wget curl

PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')

# ====== Database Setup ======
echo "🗃 Setting up MySQL..."
DB_EXIST=$(mysql -u root -sse "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${DB_NAME}'")
USER_EXIST=$(mysql -u root -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '${DB_USER}')")

if [[ "$DB_EXIST" == "$DB_NAME" || "$USER_EXIST" == "1" ]]; then
    echo "⚠️ Database or user already exists."
    read -p "Do you want to delete and recreate the database/user? (y/N): " DB_CONFIRM
    if [[ "$DB_CONFIRM" =~ ^[Yy]$ ]]; then
        mysql -u root <<EOF
DROP DATABASE IF EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'localhost';
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    else
        echo "❌ Installation aborted to avoid conflict with existing DB/user."
        exit 1
    fi
else
    mysql -u root <<EOF
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
fi

# ====== Clean Previous Install ======
if [ -f "${INSTALL_DIR}/config/config.php" ]; then
    echo "⚠️ Detected existing Nextcloud config."
    read -p "Do you want to remove the existing installation? (y/N): " CLEAN_CONFIRM
    if [[ "$CLEAN_CONFIRM" =~ ^[Yy]$ ]]; then
        echo "🧹 Cleaning previous installation..."
        rm -rf "${INSTALL_DIR}"
    else
        echo "❌ Installation aborted."
        exit 1
    fi
fi

# ====== Enable & Start Services ======
systemctl enable redis-server mariadb nginx php${PHP_VER}-fpm
systemctl start redis-server mariadb nginx php${PHP_VER}-fpm

# ====== Configure Redis for PHP Sessions ======
echo "⚙️ Configuring PHP Redis session..."
echo "session.save_handler = redis" > "/etc/php/${PHP_VER}/fpm/conf.d/redis-session.ini"
echo "session.save_path = \"tcp://127.0.0.1:6379\"" >> "/etc/php/${PHP_VER}/fpm/conf.d/redis-session.ini"

# ====== Download and Install Nextcloud ======
echo "⬇️ Downloading Nextcloud..."
wget -q https://download.nextcloud.com/server/releases/latest.zip -O /tmp/latest.zip
unzip -oq /tmp/latest.zip -d /var/www/
chown -R www-data:www-data "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"

# ====== Configure Nginx ======
echo "🌐 Configuring Nginx..."

# php-handler upstream
cat > /etc/nginx/conf.d/php-handler.conf <<EOF
upstream php-handler {
    server unix:/run/php/php${PHP_VER}-fpm.sock;
}
EOF

# Main site config
cat > /etc/nginx/sites-available/nextcloud <<EOF
server {
    listen ${PORT};
    server_name ${DOMAIN};

    root ${INSTALL_DIR};
    client_max_body_size 512M;
    fastcgi_buffers 64 4K;
    index index.php index.html /index.php\$request_uri;

    access_log /var/log/nginx/nextcloud_access.log;
    error_log /var/log/nginx/nextcloud_error.log;

    location / {
        rewrite ^ /index.php\$request_uri;
    }

    location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
        deny all;
    }

    location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
        deny all;
    }

    location ~ \.php(?:\$|/) {
        fastcgi_split_path_info ^(.+?\.php)(/.*)\$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_param HTTPS off;
        fastcgi_pass php-handler;
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
    }

    location ~ \.(?:css|js|woff2?|svg|gif|map)\$ {
        try_files \$uri /index.php\$request_uri;
        access_log off;
        expires 6M;
        add_header Cache-Control "public";
    }

    location ~ \.(?:png|html|ttf|ico|jpg|jpeg|bcmap)\$ {
        try_files \$uri /index.php\$request_uri;
        access_log off;
        expires 6M;
        add_header Cache-Control "public";
    }
}
EOF

ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/

# ====== Restart PHP-FPM before reloading NGINX ======
systemctl restart php${PHP_VER}-fpm

# ====== Reload NGINX ======
nginx -t && systemctl reload nginx

# ====== Install Nextcloud (Silent) ======
echo "🚀 Installing Nextcloud..."
sudo -u www-data php ${INSTALL_DIR}/occ maintenance:install \
  --database "mysql" \
  --database-name "${DB_NAME}" \
  --database-user "${DB_USER}" \
  --database-pass "${DB_PASS}" \
  --admin-user "${NC_ADMIN}" \
  --admin-pass "${NC_PASS}"

# ====== Configure Nextcloud ======
sudo -u www-data php ${INSTALL_DIR}/occ config:system:set trusted_domains 1 --value="${DOMAIN}"
sudo -u www-data php ${INSTALL_DIR}/occ config:system:set memcache.local --value='\OC\Memcache\Redis'
sudo -u www-data php ${INSTALL_DIR}/occ config:system:set redis host --value="127.0.0.1" --type=string
sudo -u www-data php ${INSTALL_DIR}/occ config:system:set redis port --value="6379" --type=integer
sudo -u www-data php ${INSTALL_DIR}/occ config:system:set redis timeout --value="0.0" --type=float

# ====== Output Info ======
echo ""
echo "✅ Nextcloud installation completed successfully!"
echo "=================================================="
echo "🌍 Access URL: http://${DOMAIN}:${PORT}"
echo "📁 Install Path: ${INSTALL_DIR}"
echo "👤 Admin User: ${NC_ADMIN}"
echo "🔑 Admin Pass: ${NC_PASS}"
echo "🗄 DB Name: ${DB_NAME}"
echo "👤 DB User: ${DB_USER}"
echo "🔐 DB Pass: ${DB_PASS}"
echo "=================================================="
