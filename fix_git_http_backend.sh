#!/bin/bash

set -e

echo "Meuse Registry Git HTTP Backend Fix Script"
echo "======================================="
echo 

# 1. Update the config.yaml file
echo "Updating config.yaml..."
sed -i 's|url: "http://localhost:8080/git/index.git"|url: "https://cargo.surfshield.org/git/index.git"|g' /root/meuse-registry/config/config.yaml
echo "✅ config.yaml updated"

# 2. Download updated nginx.conf and docker-compose.yml
echo "Downloading updated configuration files..."
wget -q -O /root/meuse-registry/nginx.conf.new https://raw.githubusercontent.com/mokhtarabadi/meuse/master/nginx.conf
wget -q -O /root/meuse-registry/docker-compose.yml.new https://raw.githubusercontent.com/mokhtarabadi/meuse/master/docker-compose.yml

echo "Backing up original files..."
cp /root/meuse-registry/nginx.conf /root/meuse-registry/nginx.conf.bak
cp /root/meuse-registry/docker-compose.yml /root/meuse-registry/docker-compose.yml.bak

echo "Applying new configuration files..."
mv /root/meuse-registry/nginx.conf.new /root/meuse-registry/nginx.conf
mv /root/meuse-registry/docker-compose.yml.new /root/meuse-registry/docker-compose.yml
echo "✅ Configuration files updated"

# 3. Update Nginx configuration
echo "Creating a Git HTTP backend for main Nginx..."

NGINX_CONF="/etc/nginx/sites-available/cargo.surfshield.org"
GIT_LOCATION="\n    # Git HTTP backend\n    location /git/ {\n        client_max_body_size 0;\n        proxy_pass http://127.0.0.1:8080;\n        proxy_set_header Host \$host;\n        proxy_set_header X-Real-IP \$remote_addr;\n        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Proto \$scheme;\n    }\n"

# Check if Git location already exists
if grep -q "location /git/" "$NGINX_CONF"; then
    echo "Git location already exists in Nginx config"
else
    # Add Git location before the closing brace
    sed -i "/^}/i\$GIT_LOCATION" "$NGINX_CONF"
    echo "✅ Added Git location to Nginx config"
fi

# 4. Restart services
echo "Restarting Nginx..."
systemctl restart nginx
echo "✅ Nginx restarted"

echo "Restarting Meuse containers..."
cd /root/meuse-registry
docker compose down
docker compose up -d
echo "✅ Meuse containers restarted"

echo 
echo "Done! The Git HTTP backend should now be accessible at https://cargo.surfshield.org/git/index.git"
echo "Test it with: curl -I https://cargo.surfshield.org/git/index.git/info/refs?service=git-upload-pack"
echo "You should now be able to publish crates to your registry."