#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Cleanup function
cleanup_on_error() {
    if [[ $? -ne 0 ]]; then
        print_error "Installation failed! Cleaning up..."
        if [[ -d "$PROJECT_DIR" ]]; then
            cd "$PROJECT_DIR" 2>/dev/null && docker compose down -v 2>/dev/null || true
        fi
        print_info "You can restart the installation after fixing any issues."
    fi
}

# Set trap to cleanup on error
trap cleanup_on_error EXIT

# Banner
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║            Meuse Registry Installer               ║
║     Private Rust Crate Registry with SSL         ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
print_step "Checking prerequisites..."

if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command_exists git; then
    print_error "Git is not installed. Please install Git first."
    exit 1
fi

if ! command_exists openssl; then
    print_error "OpenSSL is not installed. Please install OpenSSL first."
    exit 1
fi

# Check for docker compose
if ! docker compose version >/dev/null 2>&1; then
    print_error "Docker Compose V2 is required. Please update Docker."
    exit 1
fi

print_info "All prerequisites met!"

# Get user input
echo ""
print_step "Configuration Setup"
read -p "Enter your domain (e.g., registry.yourdomain.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    print_error "Domain is required!"
    exit 1
fi

# Validate domain format (basic validation)
if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    print_error "Invalid domain format. Use alphanumeric characters, dots, and hyphens only."
    exit 1
fi

echo ""
print_step "Git Index Configuration"
echo "Choose your crate index option:"
echo "1) Use local Git repository (limited, local machine only)"
echo "2) Use GitHub fork of crates.io-index (public metadata)"
echo "3) Use self-hosted private Git repository (fully private, recommended)"
read -p "Enter your choice (1, 2, or 3): " GIT_CHOICE

if [[ "$GIT_CHOICE" == "1" ]]; then
    USE_LOCAL_GIT=true
    USE_SELFHOSTED_GIT=false
    print_info "Using local Git repository for crate index"
elif [[ "$GIT_CHOICE" == "2" ]]; then
    USE_LOCAL_GIT=false
    USE_SELFHOSTED_GIT=false
    read -p "Enter your GitHub username for the crates index: " GITHUB_USER
    if [[ -z "$GITHUB_USER" ]]; then
        print_error "GitHub username is required for GitHub option!"
        exit 1
    fi
    print_info "Using GitHub fork: https://github.com/$GITHUB_USER/crates.io-index"
elif [[ "$GIT_CHOICE" == "3" ]]; then
    USE_LOCAL_GIT=false
    USE_SELFHOSTED_GIT=true
    print_info "Using self-hosted private Git repository (fully private)"
else
    print_error "Invalid choice! Please select 1, 2, or 3"
    exit 1
fi

read -s -p "Enter admin password for Meuse: " ADMIN_PASSWORD
echo ""
if [[ -z "$ADMIN_PASSWORD" ]]; then
    print_error "Admin password is required!"
    exit 1
fi

# Create project directory
PROJECT_DIR="meuse-registry"
print_step "Creating project directory: $PROJECT_DIR"

if [[ -d "$PROJECT_DIR" ]]; then
    read -p "Directory $PROJECT_DIR exists. Remove it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_DIR"
    else
        print_error "Installation cancelled."
        exit 1
    fi
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Download configuration files
print_step "Downloading configuration files..."

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
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
    volumes:
      - ./config:/app/config:ro
      - meuse_crates:/app/crates
EOF

if [[ "$USE_LOCAL_GIT" == "true" ]]; then
  cat >> docker-compose.yml << 'EOF'
      - ./index:/app/index
EOF
elif [[ "$USE_SELFHOSTED_GIT" == "true" ]]; then
  cat >> docker-compose.yml << 'EOF'
      - ./index:/app/index
      - ./git-repos:/app/git-repos
EOF
else
  cat >> docker-compose.yml << 'EOF'
      - ./index:/app/index:ro
EOF
fi

cat >> docker-compose.yml << 'EOF'
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

EOF

if [[ "$USE_SELFHOSTED_GIT" == "true" ]]; then
  cat >> docker-compose.yml << 'EOF'
  fcgiwrap:
    image: alpine:latest
    container_name: meuse-fcgiwrap
    command: sh -c "apk add --no-cache fcgiwrap git && fcgiwrap -s unix:/var/run/fcgiwrap.socket -f"
    volumes:
      - fcgiwrap_socket:/var/run
      - ./git-repos:/app/git-repos
    networks:
      - meuse_network
    restart: unless-stopped

EOF
fi

cat >> docker-compose.yml << 'EOF'
volumes:
  postgres_data:
  meuse_crates:
  meuse_logs:
EOF

if [[ "$USE_SELFHOSTED_GIT" == "true" ]]; then
  cat >> docker-compose.yml << 'EOF'
  fcgiwrap_socket:
EOF
fi

cat >> docker-compose.yml << 'EOF'

networks:
  meuse_network:
    driver: bridge
EOF

# Create nginx.conf (simplified version)
if [[ "$USE_SELFHOSTED_GIT" == "true" ]]; then
  cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream meuse_backend {
        server meuse:8855;
    }

    server {
        listen 80;
        server_name _;
        
        location / {
            proxy_pass http://meuse_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # Git HTTP backend for private repository access
        location ~ /git(/.*) {
            fastcgi_pass  unix:/var/run/fcgiwrap.socket;
            include       fastcgi_params;
            fastcgi_param SCRIPT_FILENAME /usr/lib/git-core/git-http-backend;
            fastcgi_param GIT_HTTP_EXPORT_ALL "";
            fastcgi_param GIT_PROJECT_ROOT /app/git-repos;
            fastcgi_param PATH_INFO $1;
            fastcgi_param REQUEST_METHOD $request_method;
            fastcgi_param QUERY_STRING $query_string;
            fastcgi_param CONTENT_TYPE $content_type;
            fastcgi_param CONTENT_LENGTH $content_length;
        }
    }
}
EOF
else
  cat > nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream meuse_backend {
        server meuse:8855;
    }

    server {
        listen 80;
        server_name _;
        
        location / {
            proxy_pass http://meuse_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF
fi

# Create directories
mkdir -p config logs/nginx

# Generate secure passwords BEFORE creating config
print_step "Generating secure passwords..."
POSTGRES_PASS=$(openssl rand -base64 32)
FRONTEND_SECRET=$(openssl rand -hex 32)

# Create configuration file
cat > config/config.yaml << EOF
database:
  user: "meuse"
  password: !secret "${POSTGRES_PASS}"
  host: "postgres"
  port: 5432
  name: "meuse"

http:
  address: "0.0.0.0"
  port: 8855

logging:
  level: "info"
  console:
    encoder: "json"

metadata:
  type: "shell"
  path: "/app/index"
EOF

if [[ "$USE_LOCAL_GIT" == "true" ]]; then
  cat >> config/config.yaml << EOF
  target: "master"
  url: "file:///app/index"
EOF
elif [[ "$USE_SELFHOSTED_GIT" == "true" ]]; then
  cat >> config/config.yaml << EOF
  target: "master"
  url: "https://${DOMAIN}/git/index.git"
EOF
else
  cat >> config/config.yaml << EOF
  target: "origin/master"
  url: "https://github.com/${GITHUB_USER}/crates.io-index"
EOF
fi

cat >> config/config.yaml << EOF

crate:
  store: "filesystem"
  path: "/app/crates"

frontend:
  enabled: true
  public: true
EOF

# Create .env file
cat > .env << EOF
POSTGRES_PASSWORD=${POSTGRES_PASS}
MEUSE_FRONTEND_SECRET=${FRONTEND_SECRET}
DOMAIN=${DOMAIN}
EOF

print_info "Configuration files created!"

# Setup Git index
print_step "Setting up Git crate index..."

if [[ "$USE_LOCAL_GIT" == "true" ]]; then
    if [[ ! -d "index" ]]; then
        print_info "Initializing local Git repository for crate index..."
        mkdir -p index
        cd index
        git init
        
        # Set up Git user for the repository
        git config user.name "Meuse Registry"
        git config user.email "registry@${DOMAIN}"
        
        # Create the crate index structure
        mkdir -p 1 2 3
        
        # Create index config with HTTP protocol (SSL can be added later with reverse proxy)
        cat > config.json << EOF
{
    "dl": "http://${DOMAIN}:8080/api/v1/crates",
    "api": "http://${DOMAIN}:8080",
    "allowed-registries": []
}
EOF
        
        # Create README for the index
        cat > README.md << EOF
# Local Crate Index for Meuse Registry

This is a local Git repository serving as the crate index for our private Rust registry.

Domain: ${DOMAIN}
Generated: $(date)

Structure:
- 1/ : crates with 1-character names
- 2/ : crates with 2-character names  
- 3/ : crates with 3-character names
- ab/cd/ : crates with 4+ character names (first 2 chars / next 2 chars)

Each crate has a file containing JSON metadata for each version.
EOF
        
        git add .
        git commit -m "Initialize local crate registry index for ${DOMAIN}"
        cd ..
        print_info "Local Git crate index created successfully!"
    fi
elif [[ "$USE_SELFHOSTED_GIT" == "true" ]]; then
    if [[ ! -d "index" ]]; then
        print_info "Initializing self-hosted private Git repository for crate index..."
        mkdir -p index
        cd index
        git init
        
        # Set up Git user for the repository
        git config user.name "Meuse Registry"
        git config user.email "registry@${DOMAIN}"
        
        # Create the crate index structure
        mkdir -p 1 2 3
        
        # Create index config with HTTPS protocol for external access
        cat > config.json << EOF
{
    "dl": "https://${DOMAIN}/api/v1/crates",
    "api": "https://${DOMAIN}",
    "allowed-registries": []
}
EOF
        
        # Create README for the index
        cat > README.md << EOF
# Self-hosted Private Crate Index for Meuse Registry

This is a self-hosted private Git repository serving as the crate index for our private Rust registry.

Domain: ${DOMAIN}
Generated: $(date)

Structure:
- 1/ : crates with 1-character names
- 2/ : crates with 2-character names  
- 3/ : crates with 3-character names
- ab/cd/ : crates with 4+ character names (first 2 chars / next 2 chars)

Each crate has a file containing JSON metadata for each version.
EOF
        
        git add .
        git commit -m "Initialize self-hosted private crate registry index for ${DOMAIN}"
        cd ..
        
        # Create bare repository for HTTP access
        print_info "Creating bare Git repository for HTTP access..."
        mkdir -p git-repos
        git clone --bare index git-repos/index.git
        
        # Configure bare repository
        cd git-repos/index.git
        git config http.receivepack true
        git config http.uploadpack true
        cd ../..
        
        print_info "Self-hosted private Git crate index created successfully!"
    fi
elif [[ "$USE_LOCAL_GIT" == "false" ]]; then
    if [[ ! -d "index" ]]; then
        print_info "Cloning crates.io index fork..."
        git clone "https://github.com/${GITHUB_USER}/crates.io-index.git" index || {
            print_error "Failed to clone Git index. Make sure you have forked https://github.com/rust-lang/crates.io-index"
            print_error "Fork it at: https://github.com/rust-lang/crates.io-index"
            exit 1
        }
    fi

    # Configure the index
    cd index
    print_info "Configuring index for domain: $DOMAIN"

    cat > config.json << EOF
{
    "dl": "http://${DOMAIN}:8080/api/v1/crates",
    "api": "http://${DOMAIN}:8080",
    "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

    # Commit and push if needed
    if ! git diff --quiet --exit-code config.json 2>/dev/null; then
        print_info "Committing index configuration..."
        git add config.json
        git commit -m "Configure index for Meuse registry at ${DOMAIN}"
        
        print_info "Pushing to GitHub..."
        if ! git push origin master 2>/dev/null; then
            print_warning "Could not push to GitHub. You may need to configure Git credentials."
            print_info "You can push manually later with: cd index && git push origin master"
        fi
    fi
    cd ..
fi

# Deploy services
print_step "Deploying services..."
docker compose up -d

print_info "Waiting for services to start..."
sleep 30

# Check service status
if ! docker compose ps | grep -q "Up"; then
    print_error "Services failed to start properly"
    print_info "Check logs with: docker compose logs"
    exit 1
fi

# Create admin user
print_step "Creating admin user..."

# Wait a bit more for Meuse to be fully ready
print_info "Waiting for services to fully initialize..."
sleep 30

# Check if services are actually healthy
print_info "Verifying service health..."
for i in {1..10}; do
    if curl -f -s http://localhost:8080/healthz > /dev/null 2>&1; then
        print_info "Services are healthy!"
        break
    else
        if [ $i -eq 10 ]; then
            print_error "Services failed to become healthy after 100 seconds"
            print_info "Check logs with: docker compose logs"
            exit 1
        fi
        print_info "Waiting for services... attempt $i/10"
        sleep 10
    fi
done

# Generate password hash with retry logic
print_info "Generating password hash..."
for i in {1..3}; do
    PASSWORD_HASH=$(docker compose exec -T meuse java -jar /app/meuse.jar password "$ADMIN_PASSWORD" 2>/dev/null | grep '$2a$' | tail -1)
    
    if [[ -n "$PASSWORD_HASH" ]]; then
        print_info "Password hash generated successfully!"
        break
    else
        if [ $i -eq 3 ]; then
            print_error "Failed to generate password hash after 3 attempts"
            print_info "You can create the admin user manually after setup:"
            print_info "1. Generate hash: docker compose exec meuse java -jar /app/meuse.jar password YOUR_PASSWORD"
            print_info "2. Insert user: docker compose exec postgres psql -U meuse -d meuse"
            print_warning "Continuing with setup..."
            PASSWORD_HASH=""
            break
        fi
        print_warning "Password hash generation failed, retrying... ($i/3)"
        sleep 5
    fi
done

# Create admin user in database (only if hash was generated)
if [[ -n "$PASSWORD_HASH" ]]; then
    print_info "Creating admin user in database..."
    if docker compose exec -T postgres psql -U meuse -d meuse << EOF
INSERT INTO users(id, name, password, description, active, role_id) 
VALUES ('f3e6888e-97f9-11e9-ae4e-ef296f05cd17', 'admin', '$PASSWORD_HASH', 'Administrator user', true, '867428a0-69ba-11e9-a674-9f6c32022150')
ON CONFLICT (id) DO NOTHING;
EOF
    then
        print_info "Admin user created successfully!"
    else
        print_error "Failed to create admin user in database"
    fi
fi

# Wait for API to be ready and create token (only if user was created)
if [[ -n "$PASSWORD_HASH" ]]; then
    print_info "Creating API token..."
    sleep 5

    # Try to create token with retry logic and better error handling
    TOKEN=""
    for i in {1..3}; do
        RESPONSE=$(curl -s --max-time 15 --header "Content-Type: application/json" --request POST \
            --data "{\"name\":\"admin_token_$(date +%s)\",\"validity\":365,\"user\":\"admin\",\"password\":\"$ADMIN_PASSWORD\"}" \
            http://localhost:8080/api/v1/meuse/token 2>/dev/null)
        
        if [[ $? -eq 0 ]] && echo "$RESPONSE" | grep -q '"token":'; then
            TOKEN=$(echo "$RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
            if [[ -n "$TOKEN" ]]; then
                print_info "API token created successfully!"
                break
            fi
        fi
        
        if [ $i -eq 3 ]; then
            print_warning "Could not create API token automatically after 3 attempts."
            print_info "You can create it manually with:"
            print_info "curl --header \"Content-Type: application/json\" --request POST \\"
            print_info "  --data '{\"name\":\"my_token\",\"validity\":365,\"user\":\"admin\",\"password\":\"$ADMIN_PASSWORD\"}' \\"
            print_info "  http://localhost:8080/api/v1/meuse/token"
        else
            print_warning "Token creation failed, retrying... ($i/3)"
            sleep 5
        fi
    done
fi

check_health() {
    print_info "Checking service health..."
    
    max_attempts=10
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s http://localhost:8080/healthz > /dev/null 2>&1; then
            print_info "Health check passed!"
            break
        else
            print_info "Health check attempt $attempt/$max_attempts failed, retrying..."
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Health checks failed after $max_attempts attempts"
        print_info "Check the logs with: docker-compose logs"
        exit 1
    fi
}

check_health

# Success message
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗"
echo -e "║              🎉 SUCCESS! 🎉                      ║"
echo -e "║        Meuse Registry is now running!            ║"
echo -e "╚═══════════════════════════════════════════════════╝${NC}"
echo ""

print_info "📊 Setup Summary:"
echo "  🌐 Domain: $DOMAIN"
if [[ "$USE_LOCAL_GIT" == "true" ]]; then
    echo "  📋 Git Index: Local repository (file:///app/index)"
elif [[ "$USE_SELFHOSTED_GIT" == "true" ]]; then
    echo "  📋 Git Index: Self-hosted private repository (http://localhost:8080/api/v1/crates)"
else
    echo "  📋 Git Index: GitHub fork (https://github.com/$GITHUB_USER/crates.io-index)"
fi
echo "  👤 Admin user: admin"  
echo "  🔑 Admin password: $ADMIN_PASSWORD"
if [[ -n "$TOKEN" ]]; then
    echo "  🎫 API Token: $TOKEN"
fi
echo "  📁 Project directory: $(pwd)"
echo ""

print_info "📋 Useful commands:"
echo "  docker-compose logs -f meuse    # View Meuse logs"
echo "  docker-compose ps               # Check service status"
echo "  docker-compose down             # Stop all services"
echo "  docker-compose up -d            # Start services"
echo ""

print_info "🌐 Access your registry:"
echo "  Registry URL: http://${DOMAIN}:8080"
echo "  Health check: curl http://localhost:8080/healthz"
echo "  Web interface: http://${DOMAIN}:8080 (if frontend enabled)"
echo ""

print_info "🔧 Documentation: See DOCKER_SETUP.md for complete setup guide"
echo ""

print_warning "📝 Don't forget to:"
if [[ "$USE_LOCAL_GIT" == "true" ]]; then
    echo "- Your local registry is ready to use!"
    echo "- Configure Cargo to point to http://${DOMAIN}:8080"
elif [[ "$USE_SELFHOSTED_GIT" == "true" ]]; then
    echo "- Your self-hosted private registry is ready to use!"
    echo "- Configure Cargo to point to http://${DOMAIN}:8080"
else
    echo "- Configure your GitHub fork if needed"
    echo "- Set up SSL for production use"
    echo "- Configure Cargo to point to http://${DOMAIN}:8080"
fi