#!/bin/bash

set -e

echo "Meuse Registry Git Configuration Fix Script"
echo "========================================="
echo 

cd /root/meuse-registry

# Create Git global config script
echo "Creating Git configuration script..."
cat > git-config-script.sh << 'EOF'
#!/bin/bash
# This script configures Git globally inside the container

# Set up Git global configuration
git config --global pull.rebase false
git config --global user.name "Meuse Registry"
git config --global user.email "registry@surfshield.org"
git config --global init.defaultBranch master

# Initialize Git repo if needed
if [ -d "/app/index" ]; then
  cd /app/index
  if [ ! -d ".git" ]; then
    echo "Initializing Git repository in /app/index"
    git init
    git add .
    git commit -m "Initial commit"
  fi
  
  # Configure remote if it doesn't exist
  if [ -d "/app/git-repos/index.git" ] && ! git remote | grep -q origin; then
    echo "Setting up Git remote"
    git remote add origin /app/git-repos/index.git
    git push -u origin master || true
  fi
fi
EOF

chmod +x git-config-script.sh
echo "✅ Git configuration script created"

# Update docker-compose.yml to include the script
echo "Updating docker-compose.yml..."

# Check if docker-compose.yml already has the volume mount
if grep -q "git-config-script.sh:/docker-entrypoint.d/git-config.sh" docker-compose.yml; then
  echo "Docker compose file already configured"
else
  # Create a temporary file
  cat > docker-compose.yml.new << EOF
services:
  postgres:
    image: postgres:14.4
    container_name: meuse-postgres
    environment:
      POSTGRES_DB: meuse
      POSTGRES_USER: meuse
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - meuse_network
    restart: unless-stopped
    healthcheck:
      test: [ "CMD-SHELL", "pg_isready -U meuse -d meuse" ]
      interval: 30s
      timeout: 10s
      retries: 5

  meuse:
    image: mokhtarabadi/meuse:latest
    container_name: meuse-app
    environment:
      - MEUSE_CONFIGURATION=/app/config/config.yaml
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - MEUSE_FRONTEND_SECRET=${MEUSE_FRONTEND_SECRET}
      - DOMAIN=${DOMAIN}
    volumes:
      - ./config:/app/config:ro
      - ./crates:/app/crates
      - ./index:/app/index
      - ./git-repos:/app/git-repos
      - ./git-config-script.sh:/docker-entrypoint.d/git-config.sh:ro
      - meuse_logs:/app/logs
    networks:
      - meuse_network
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:8855/healthz" ]
      interval: 30s
      timeout: 10s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: meuse-nginx
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./git-repos:/git-repos:ro
      - ./index:/app/index:ro
      - meuse_logs:/var/log/nginx
    ports:
      - "8080:80"
    networks:
      - meuse_network
    depends_on:
      - meuse
    restart: unless-stopped
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost/healthz" ]
      interval: 30s
      timeout: 10s
      retries: 5
    command: >
      /bin/sh -c "apk add --no-cache git fcgiwrap spawn-fcgi &&
      spawn-fcgi -s /var/run/fcgiwrap.sock -u nginx -g nginx /usr/bin/fcgiwrap &&
      chmod 777 /var/run/fcgiwrap.sock &&
      nginx -g 'daemon off;'"

volumes:
  postgres_data:
  meuse_logs:

networks:
  meuse_network:
    driver: bridge
EOF

  # Replace the existing docker-compose.yml
  mv docker-compose.yml.new docker-compose.yml
  echo "✅ Docker compose file updated"
fi

# Set proper permissions for the directories
echo "Setting correct permissions..."
chown -R 999:999 ./index
chown -R 999:999 ./crates
chown -R 999:999 ./git-repos
chmod -R 755 ./index
chmod -R 755 ./crates
chmod -R 755 ./git-repos
echo "✅ Permissions set"

# Make sure Git repo is properly initialized
echo "Ensuring Git repository is properly initialized..."

# Initialize index Git repository if needed
cd /root/meuse-registry/index
if [ ! -d ".git" ]; then
  git init
  git config user.name "Meuse Registry"
  git config user.email "registry@surfshield.org"
  git config pull.rebase false
  git config init.defaultBranch master
  
  # Create necessary directories
  mkdir -p 1 2 3
  
  # Create config.json if it doesn't exist
  if [ ! -f config.json ]; then
    cat > config.json << EOF
{
    "dl": "https://cargo.surfshield.org/api/v1/crates",
    "api": "https://cargo.surfshield.org",
    "allowed-registries": []
}
EOF
  fi
  
  git add .
  git commit -m "Initial commit" || true
fi

# Create bare repo if it doesn't exist
cd /root/meuse-registry
if [ ! -d "git-repos/index.git" ]; then
  mkdir -p git-repos
  git clone --bare index git-repos/index.git
  cd git-repos/index.git
  git config http.receivepack true
  git config http.uploadpack true
fi

# Restart services
echo "Restarting Docker containers..."
cd /root/meuse-registry
docker compose down
docker compose up -d
echo "✅ Containers restarted"

echo 
echo "Done! The Git pull strategy issue should now be fixed."
echo "Your Meuse registry should work correctly with both Git and sparse protocols."
echo 
echo "To test if it's working:"
echo "1. Try publishing a crate: cargo publish --registry surfshield"
echo "2. Or check direct access: curl -I https://cargo.surfshield.org/git/index.git/info/refs"
echo 
echo "If you continue to have issues, consider switching to the sparse protocol:"
echo "  index = \"sparse+https://cargo.surfshield.org/index/\""