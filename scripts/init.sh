#!/bin/bash
# Main initialization script that determines which mode to use and executes all logic inline

set -e

# Helper function to verify directory exists
verify_dir() {
  if [ ! -d "$1" ]; then
    echo "Error: Directory $1 does not exist or failed to create"
    exit 1
  fi
}

# Helper function to verify Git operation success
verify_git() {
  if [ $? -ne 0 ]; then
    echo "Error: Git operation failed: $1"
    exit 1
  fi
  echo "✓ Git operation successful: $1"
}

# Default to local mode if not specified
MODE=${MEUSE_INIT_MODE:-local}

# Get domain from environment variable or default to localhost
DOMAIN=${DOMAIN:-localhost}

# Default protocol - can be overridden with MEUSE_PROTOCOL=https in environment
PROTOCOL=${MEUSE_PROTOCOL:-http}

echo "Using initialization mode: $MODE"
echo "Using domain: $DOMAIN with protocol: $PROTOCOL"

case $MODE in
  local)
    echo "Initializing local Git repository..."

    # Clean and recreate index contents with proper ownership
    rm -rf /app/index/* /app/index/.git 2>/dev/null || true
    mkdir -p /app/index/1 /app/index/2 /app/index/3
    verify_dir "/app/index"

    # Initialize Git repository
    git -C /app/index init
    verify_git "git init"
    
    git -C /app/index config user.name "Meuse Registry"
    git -C /app/index config user.email "registry@example.com"

    # Verify .git directory exists after initialization
    if [ ! -d "/app/index/.git" ]; then
      echo "Error: Git repository initialization failed - .git directory not found"
      exit 1
    fi

    # Create config.json
    cat > /app/index/config.json << EOF
{
  "dl": "${PROTOCOL}://${DOMAIN}:8080/api/v1/crates",
  "api": "${PROTOCOL}://${DOMAIN}:8080",
  "allowed-registries": []
}
EOF

    # Verify config.json was created
    if [ ! -f "/app/index/config.json" ]; then
      echo "Error: Failed to create config.json"
      exit 1
    fi
    echo "✓ Created config.json"

    # Commit initial structure
    git -C /app/index add .
    git -C /app/index commit -m "Initialize local crate registry index"
    verify_git "git commit"

    # Create git-repos directory if it doesn't exist
    mkdir -p /app/git-repos
    verify_dir "/app/git-repos"

    # Create bare repository for HTTP access
    git clone --bare /app/index /app/git-repos/index.git
    verify_git "git clone --bare"
    
    verify_dir "/app/git-repos/index.git"
    
    git -C /app/git-repos/index.git config http.receivepack true
    git -C /app/git-repos/index.git config http.uploadpack true

    echo "Local Git repository initialized successfully!"
    echo "Index location: /app/index"
    echo "Bare repository: /app/git-repos/index.git"
    ;;  
  github)
    echo "Initializing GitHub fork repository..."

    # Check if GITHUB_REPO_URL is provided
    if [ -z "$GITHUB_REPO_URL" ]; then
        echo "Error: GITHUB_REPO_URL environment variable is required"
        echo "Example: GITHUB_REPO_URL=https://github.com/YOUR_USERNAME/crates.io-index"
        exit 1
    fi

    # Create index directory
    mkdir -p /app/index
    verify_dir "/app/index"

    # Clone the GitHub fork
    cd /app/index
    git clone "$GITHUB_REPO_URL" .
    verify_git "git clone from GitHub"

    # Verify .git directory exists after cloning
    if [ ! -d "/app/index/.git" ]; then
      echo "Error: GitHub repository cloning failed - .git directory not found"
      exit 1
    fi

    # Configure the index for your domain
    cat > config.json << EOF
{
  "dl": "${PROTOCOL}://${DOMAIN}:8080/api/v1/crates",
  "api": "${PROTOCOL}://${DOMAIN}:8080",
  "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

    # Verify config.json was created
    if [ ! -f "/app/index/config.json" ]; then
      echo "Error: Failed to create config.json"
      exit 1
    fi
    echo "✓ Created config.json"

    # Commit the configuration changes
    git add config.json
    git commit -m "Configure for Meuse registry"
    verify_git "git commit"

    # Create git-repos directory if it doesn't exist
    mkdir -p /app/git-repos
    verify_dir "/app/git-repos"

    # Create bare repository for HTTP access
    cd /app
    git clone --bare index git-repos/index.git
    verify_git "git clone --bare"
    
    verify_dir "/app/git-repos/index.git"
    
    cd git-repos/index.git
    git config http.receivepack true
    git config http.uploadpack true

    echo "GitHub fork repository initialized successfully!"
    echo "GitHub repo: $GITHUB_REPO_URL"
    echo "Index location: /app/index"
    echo "Bare repository: /app/git-repos/index.git"
    ;;
  sparse)
    echo "Initializing sparse protocol index..."

    # Create index directory structure
    mkdir -p /app/index/1 /app/index/2 /app/index/3
    verify_dir "/app/index"
    verify_dir "/app/index/1"
    verify_dir "/app/index/2"
    verify_dir "/app/index/3"

    # Create config.json for sparse protocol
    cat > /app/index/config.json << EOF
{
  "dl": "${PROTOCOL}://${DOMAIN}:8080/api/v1/crates",
  "api": "${PROTOCOL}://${DOMAIN}:8080",
  "allowed-registries": []
}
EOF

    # Verify config.json was created
    if [ ! -f "/app/index/config.json" ]; then
      echo "Error: Failed to create config.json"
      exit 1
    fi
    echo "✓ Created config.json"

    echo "Sparse protocol index initialized successfully!"
    echo "Index location: /app/index"
    echo "No Git repository needed for sparse protocol"
    ;;
  *)
    echo "Unknown init mode '$MODE'. Use MEUSE_INIT_MODE=local|github|sparse"
    exit 1
    ;;
esac

# Ensure required directories exist and proper ownership
# Create crates and logs directories so volumes mounted to the init container are initialized
mkdir -p /app/crates /app/logs 2>/dev/null || true
verify_dir "/app/crates"
verify_dir "/app/logs"

# Set proper ownership for all directories
echo "Setting proper permissions (UID/GID: 999:999)..."
chown -R 999:999 /app/index /app/git-repos /app/crates /app/logs 2>/dev/null || true

echo "✓ Initialization completed successfully!"
echo "Note: Wait at least 45 seconds before creating users to allow services to fully initialize."