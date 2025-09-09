#!/bin/bash
# Main initialization script that determines which mode to use and executes all logic inline

set -e

# Default to local mode if not specified
MODE=${MEUSE_INIT_MODE:-local}

echo "Using initialization mode: $MODE"

case $MODE in
  local)
    echo "Initializing local Git repository..."

    # Clean and recreate index contents with proper ownership
    rm -rf /app/index/* /app/index/.git 2>/dev/null || true
    mkdir -p /app/index/1 /app/index/2 /app/index/3

    # Initialize Git repository
    git -C /app/index init
    git -C /app/index config user.name "Meuse Registry"
    git -C /app/index config user.email "registry@example.com"

    # Create config.json
    cat > /app/index/config.json << 'EOF'
{
  "dl": "http://localhost:8080/api/v1/crates",
  "api": "http://localhost:8080",
  "allowed-registries": []
}
EOF

    # Commit initial structure
    git -C /app/index add .
    git -C /app/index commit -m "Initialize local crate registry index"

    # Create bare repository for HTTP access
    git clone --bare /app/index /app/git-repos/index.git
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

    # Clone the GitHub fork
    cd /app/index
    git clone "$GITHUB_REPO_URL" .

    # Configure the index for your domain
    cat > config.json << EOF
{
  "dl": "http://localhost:8080/api/v1/crates",
  "api": "http://localhost:8080",
  "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

    # Commit the configuration changes
    git add config.json
    git commit -m "Configure for Meuse registry"

    # Create bare repository for HTTP access
    cd /app
    git clone --bare index git-repos/index.git
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

    # Create config.json for sparse protocol
    cat > /app/index/config.json << EOF
{
  "dl": "http://localhost:8080/api/v1/crates",
  "api": "http://localhost:8080",
  "allowed-registries": []
}
EOF

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
chown -R 999:999 /app/index /app/git-repos /app/crates /app/logs 2>/dev/null || true

echo "Initialization completed successfully!"