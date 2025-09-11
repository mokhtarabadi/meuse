#!/usr/bin/env bash
set -euo pipefail

# Initialize the Docker environment for Meuse
# This script creates the necessary directories and Git repository structure
# before running Docker Compose

# Display colorful messages
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
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

prompt() {
  echo -e "${BLUE}[INPUT]${NC} $1"
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

# Get domain and URL information from user
echo -e "\n${YELLOW}=== Registry Configuration ===${NC}"

# Check if non-interactive mode is requested
NON_INTERACTIVE=${NON_INTERACTIVE:-0}
if [[ -n "${DOMAIN:-}" && -n "${GIT_URL:-}" && -n "${CARGO_URL:-}" ]]; then
  NON_INTERACTIVE=1
  info "Using provided environment variables for configuration"
fi

if [[ $NON_INTERACTIVE -eq 0 ]]; then
  # Interactive mode
  prompt "Enter your domain name (e.g., example.com): "
  read -r DOMAIN_INPUT
  DOMAIN=${DOMAIN_INPUT:-localhost}
  
  # Default URLs based on domain
  DEFAULT_GIT_URL="https://git.${DOMAIN}/myindex.git"
  DEFAULT_CARGO_URL="https://cargo.${DOMAIN}"
  
  prompt "Enter Git repository URL [${DEFAULT_GIT_URL}]: "
  read -r GIT_URL_INPUT
  GIT_URL=${GIT_URL_INPUT:-$DEFAULT_GIT_URL}
  
  prompt "Enter Cargo registry URL [${DEFAULT_CARGO_URL}]: "
  read -r CARGO_URL_INPUT
  CARGO_URL=${CARGO_URL_INPUT:-$DEFAULT_CARGO_URL}
  
  echo -e "\n${YELLOW}=== Configuration Summary ===${NC}"
  echo -e "Domain: ${GREEN}${DOMAIN}${NC}"
  echo -e "Git URL: ${GREEN}${GIT_URL}${NC}"
  echo -e "Cargo URL: ${GREEN}${CARGO_URL}${NC}"
  
  prompt "Is this correct? [Y/n]: "
  read -r CONFIRM
  if [[ "${CONFIRM,,}" == "n" ]]; then
    error "Configuration aborted. Please run the script again."
  fi
else
  # Non-interactive mode
  info "Using domain: ${DOMAIN}"
  info "Using Git URL: ${GIT_URL}"
  info "Using Cargo URL: ${CARGO_URL}"
fi

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
  warn "Git repository already exists, checking if it needs initialization"
fi

# Check if repository is already initialized with config.json
cd myindex.git
if git show-ref --quiet refs/heads/master; then
  warn "Repository already has a master branch, skipping initialization"
  cd ../..
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
  
  info "Environment already initialized"
  info "You can now run 'docker compose up -d' to start the services"
  exit 0
fi

# Create config.json for Cargo with domain-specific URLs
info "Creating config.json for Cargo"
cat > ../config.json << EOF
{
  "dl": "${CARGO_URL}/api/v1/crates",
  "api": "${CARGO_URL}",
  "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

# Properly initialize the Git repository using Git plumbing commands
info "Initializing Git repository with config.json"

# Create blob object
info "Creating blob object for config.json"
BLOB_HASH=$(git hash-object -w ../config.json)
info "Blob hash: ${BLOB_HASH}"

# Create tree object
info "Creating tree object with config.json"
TREE_HASH=$(echo -e "100644 blob ${BLOB_HASH}\tconfig.json" | git mktree)
info "Tree hash: ${TREE_HASH}"

# Set Git author and committer information
export GIT_AUTHOR_NAME="Meuse Admin"
export GIT_AUTHOR_EMAIL="admin@${DOMAIN}"
export GIT_COMMITTER_NAME="Meuse Admin"
export GIT_COMMITTER_EMAIL="admin@${DOMAIN}"

# Create commit object
info "Creating commit object"
COMMIT_HASH=$(git commit-tree "${TREE_HASH}" -m "Initialize registry with config.json")
info "Commit hash: ${COMMIT_HASH}"

# Update master branch reference
info "Updating master branch reference"
git update-ref refs/heads/master "${COMMIT_HASH}"

# Update server info for HTTP access
info "Updating server info for HTTP access"
git update-server-info

# Return to project root
cd ../..

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

echo -e "\n${GREEN}✓ Environment initialized successfully${NC}"
echo -e "\n${YELLOW}=== Next Steps ===${NC}"
info "1. Start the services: docker compose up -d"
info "2. Configure your Cargo client:"
echo -e "   - Add to ~/.cargo/config.toml:"
echo -e "     ${YELLOW}[registries.meuse]${NC}"
echo -e "     ${YELLOW}index = \"${GIT_URL}\"${NC}"
echo -e "     ${YELLOW}[net]${NC}"
echo -e "     ${YELLOW}git-fetch-with-cli = true${NC}"
info "3. Create a token for publishing:"
echo -e "   ${YELLOW}curl -s -X POST -H "Content-Type: application/json" \${NC}"
echo -e "   ${YELLOW}  -d '{"name":"my_token","validity":365,"user":"${ADMIN_USER:-admin}","password":"${ADMIN_PASSWORD:-admin_password}"}' \${NC}"
echo -e "   ${YELLOW}  ${CARGO_URL}/api/v1/meuse/token${NC}"
info "4. Add the token to ~/.cargo/credentials.toml:"
echo -e "   ${YELLOW}[registries.meuse]${NC}"
echo -e "   ${YELLOW}token = \"your-token-from-api-response\"${NC}"