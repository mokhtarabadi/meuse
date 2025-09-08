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

read -p "Enter your GitHub username for the crates index: " GITHUB_USER
if [[ -z "$GITHUB_USER" ]]; then
    print_error "GitHub username is required!"
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
    ports:
      - "5432:5432"
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
      - meuse_index:/app/index
      - meuse_logs:/app/logs
    ports:
      - "8855:8855"
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
      - "80:80"
      - "443:443"
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

volumes:
  postgres_data:
  meuse_crates:
  meuse_index:
  meuse_logs:

networks:
  meuse_network:
    driver: bridge
EOF

# Create nginx.conf (simplified version)
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

# Create directories
mkdir -p config logs/nginx

# Create configuration file
cat > config/config.yaml << EOF
database:
  user: "meuse"
  password: !secret "${POSTGRES_PASSWORD}"
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
  target: "origin/master"  
  url: "https://github.com/${GITHUB_USER}/crates.io-index"

crate:
  store: "filesystem"
  path: "/app/crates"

frontend:
  enabled: true
  public: true
EOF

# Generate secure passwords
print_step "Generating secure passwords..."
POSTGRES_PASS=$(openssl rand -base64 32)
FRONTEND_SECRET=$(openssl rand -hex 32)

# Create .env file
cat > .env << EOF
POSTGRES_PASSWORD=${POSTGRES_PASS}
MEUSE_FRONTEND_SECRET=${FRONTEND_SECRET}
DOMAIN=${DOMAIN}
EOF

# Update config with actual password
sed -i "s/\${POSTGRES_PASSWORD}/${POSTGRES_PASS}/g" config/config.yaml

print_info "Configuration files created!"

# Setup Git index
print_step "Setting up Git crate index..."

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
    "dl": "https://${DOMAIN}/api/v1/crates",
    "api": "https://${DOMAIN}",
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
sleep 15

# Generate password hash
print_info "Generating password hash..."
PASSWORD_HASH=$(docker compose exec -T meuse java -jar /app/meuse.jar password "$ADMIN_PASSWORD" 2>/dev/null | grep '$2a$' | tail -1)

if [[ -z "$PASSWORD_HASH" ]]; then
    print_error "Failed to generate password hash"
    exit 1
fi

# Create admin user in database
print_info "Creating admin user in database..."
docker compose exec -T postgres psql -U meuse -d meuse << EOF
INSERT INTO users(id, name, password, description, active, role_id) 
VALUES ('f3e6888e-97f9-11e9-ae4e-ef296f05cd17', 'admin', '$PASSWORD_HASH', 'Administrator user', true, '867428a0-69ba-11e9-a674-9f6c32022150')
ON CONFLICT (id) DO NOTHING;
EOF

# Wait for API to be ready and create token
print_info "Creating API token..."
sleep 5

TOKEN=$(curl -s --max-time 10 --header "Content-Type: application/json" --request POST \
    --data "{\"name\":\"admin_token\",\"validity\":365,\"user\":\"admin\",\"password\":\"$ADMIN_PASSWORD\"}" \
    http://localhost/api/v1/meuse/token | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [[ -n "$TOKEN" ]]; then
    print_info "API token created successfully!"
else
    print_warning "Could not create API token automatically. You can create it manually after setup."
fi

# Success message
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════╗"
echo -e "║              🎉 SUCCESS! 🎉                      ║"
echo -e "║        Meuse Registry is now running!            ║"
echo -e "╚═══════════════════════════════════════════════════╝${NC}"
echo ""

print_info "📊 Setup Summary:"
echo "  🌐 Domain: $DOMAIN"
echo "  👤 Admin user: admin"  
echo "  🔑 Admin password: $ADMIN_PASSWORD"
if [[ -n "$TOKEN" ]]; then
    echo "  🎫 API Token: $TOKEN"
fi
echo "  📁 Project directory: $(pwd)"
echo ""

print_info "🔗 Next Steps:"
echo "  1. Set up Cloudflare SSL (see QUICK_START.md)"
echo "  2. Configure Cargo (see QUICK_START.md)"
echo "  3. Test: curl http://localhost/healthz"
echo ""

print_info "📚 Documentation:"
echo "  • Quick Start: QUICK_START.md"  
echo "  • Full Guide: DOCKER_SETUP.md"
echo "  • Commands: docker compose ps|logs|restart"
echo ""

print_info "🎊 Your Rust registry is ready!"