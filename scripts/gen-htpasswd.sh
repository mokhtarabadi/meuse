#!/usr/bin/env bash
set -euo pipefail

# =====================================================
# Generate htpasswd file for Git HTTP authentication
# =====================================================
# This script must be run BEFORE starting the git-server container
# It creates the htpasswd file that nginx uses for authentication
# =====================================================

# Color codes
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m"

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Git HTTP Authentication Setup${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check prerequisites
if ! command -v docker >/dev/null 2>&1; then
  error "Docker is required to generate htpasswd file"
fi

# Check if we're in the project root
if [[ ! -f "docker-compose.yml" ]]; then
  error "Please run this script from the project root directory"
fi

# Load environment variables
if [[ -f ".env" ]]; then
  info "Loading environment variables from .env"
  set -a
  source ./.env
  set +a
else
  warn "No .env file found. Creating from .env.example..."
  if [[ -f ".env.example" ]]; then
    cp .env.example .env
    info ".env file created. Please review and update the values, then run this script again."
    exit 0
  else
    error ".env.example file not found. Cannot proceed."
  fi
fi

# Set defaults
GIT_USER=${GIT_USER:-gituser}
GIT_PASSWORD=${GIT_PASSWORD:-password}

# Display current configuration
echo -e "${YELLOW}Current Configuration:${NC}"
echo -e "  Git User: ${GREEN}${GIT_USER}${NC}"
echo -e "  Git Password: ${GREEN}[hidden]${NC}"
echo ""

# Check if htpasswd already exists
if [[ -f "git-data/htpasswd" ]]; then
  warn "htpasswd file already exists at git-data/htpasswd"
  read -p "Do you want to overwrite it? [y/N]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Keeping existing htpasswd file"
    exit 0
  fi
fi

# Create git-data directory if it doesn't exist
mkdir -p git-data

# Generate htpasswd using httpd container
info "Generating htpasswd file for user: ${GIT_USER}"

docker run --rm \
  -v "$(pwd)/git-data:/git-data" \
  httpd:2.4-alpine \
  htpasswd -bc /git-data/htpasswd "${GIT_USER}" "${GIT_PASSWORD}"

if [[ $? -eq 0 ]]; then
  chmod 644 git-data/htpasswd
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✅ htpasswd file generated successfully!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo -e "1. Start the services: ${BLUE}docker compose up -d${NC}"
  echo -e "2. The git-server will use this htpasswd for authentication"
  echo -e "3. Clone your registry: ${BLUE}git clone http://${GIT_USER}@localhost:8180/myindex${NC}" # Meuse now requires non-bare repositories for crate registry and publishing.
else
  error "Failed to generate htpasswd file"
fi