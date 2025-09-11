#!/bin/sh
set -e

# Create required directories with correct permissions
mkdir -p /app/git-data /app/crates /app/config

# Initialize Git repository if it doesn't exist
if [ ! -d "/app/git-data/myindex.git" ]; then
    echo "[INIT] Initializing Git repository for the first time..."
    
    # Install git if not present
    if ! command -v git >/dev/null 2>&1; then
        echo "[INIT] Git not found, installing..."
        apt-get update && apt-get install -y git
    fi
    
    # Set git configuration
    export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Meuse Admin}"
    export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-admin@${DOMAIN:-localhost}}"
    export GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-Meuse Admin}"
    export GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-admin@${DOMAIN:-localhost}}"
    
    # Create bare repository
    mkdir -p /app/git-data/myindex.git
    cd /app/git-data/myindex.git
    git init --bare
    
    # Create config.json with environment variables
    CARGO_API_URL="${CARGO_API_URL:-http://localhost:8855/api/v1/crates}"
    REGISTRY_URL="${REGISTRY_URL:-http://localhost:8855}"
    
    cat > /tmp/config.json <<EOF
{
  "dl": "${CARGO_API_URL}",
  "api": "${REGISTRY_URL}",
  "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF
    
    # Add config.json to the repository
    BLOB_HASH=$(git hash-object -w /tmp/config.json)
    # Use POSIX-compliant printf instead of echo -e for mktree
    TREE_HASH=$(printf "100644 blob ${BLOB_HASH}\tconfig.json\n" | git mktree)
    COMMIT_HASH=$(git commit-tree "${TREE_HASH}" -m "Initialize registry with config.json")
    git update-ref refs/heads/master "${COMMIT_HASH}"
    git update-server-info
    
    # Set correct permissions
    chown -R meuse:meuse /app/git-data

    echo "[INIT] Git repository initialized successfully"
    cd /app
else
    echo "[INFO] Git repository already exists, skipping initialization"
fi

# Ensure correct ownership (skip config.yaml chown, may be RO bind)
chown -R meuse:meuse /app/git-data /app/crates
# chown meuse:meuse /app/config/config.yaml || true  # Commented out to avoid read-only error

# Check if the command starts with "java" and inject JAVA_OPTS if needed
if [ "$1" = "java" ] && [ -n "${JAVA_OPTS}" ]; then
    # Inject JAVA_OPTS after "java"
    shift  # Remove "java" from arguments
    exec java ${JAVA_OPTS} "$@"
else
    # Execute the command as-is
    exec "$@"
fi