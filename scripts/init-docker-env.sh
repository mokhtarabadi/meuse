#!/usr/bin/env bash
set -euo pipefail

# Initialize the Docker environment for Meuse
# This script creates the necessary directories and Git repository structure
# before running Docker Compose

# Display colorful messages
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Check if running from project root
if [[ ! -f "docker-compose.yml" ]]; then
  error "Please run this script from the project root directory"
fi

# Check if .env file exists or create from example
if [[ ! -f ".env" ]]; then
  if [[ -f ".env.example" ]]; then
    warn "No .env file found. Creating from .env.example"
    cp .env.example .env
    info "Created .env file. Please review and adjust settings before continuing"
  else
    error ".env.example file not found"
  fi
fi

# Load environment variables
info "Loading environment variables"
source .env

# Create necessary directories
info "Creating required directories"
mkdir -p git-data crates

# Initialize Git repository
info "Initializing Git repository"
cd git-data

if [[ ! -d "myindex.git" ]]; then
  info "Creating bare Git repository"
  git init --bare myindex.git
else
  warn "Git repository already exists, skipping"
fi

# Create config.json for Cargo
info "Creating config.json for Cargo"
cat > config.json << EOF
{
  "dl": "http://localhost:${MEUSE_PORT:-8855}/api/v1/crates",
  "api": "http://localhost:${MEUSE_PORT:-8855}",
  "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

# Copy config into repository
info "Copying config.json into Git repository"
cp config.json myindex.git/
cd ..

# Generate htpasswd file if it doesn't exist
if [[ ! -f "git-data/htpasswd" ]]; then
  info "Generating htpasswd file"
  ./scripts/gen-htpasswd.sh
else
  warn "htpasswd file already exists, skipping"
fi

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  error "Docker is not running or not accessible"
fi

info "Environment initialized successfully"
info "You can now run 'docker compose up -d' to start the services"
info "After starting services, run the following to update Git repository info:"
echo -e "${YELLOW}docker compose exec git-server bash -c 'cd /srv/git/myindex.git && git update-server-info'${NC}"