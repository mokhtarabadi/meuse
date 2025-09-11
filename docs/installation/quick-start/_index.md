---
title: Quick Start Guide
weight: 15
disableToc: false
---

# Setting Up Meuse: Quick Start Guide

This guide provides a streamlined approach to set up a complete Meuse registry environment with minimal effort.

## Prerequisites

- Java (OpenJDK 11+)
- Git
- Docker and Docker Compose (for PostgreSQL)
- Cargo/Rust toolchain

## Step 1: Clone and Prepare

```bash
# Clone Meuse
git clone https://github.com/mcorbin/meuse.git
cd meuse

# Create required directories
mkdir -p index crates git-repos/index-workspace
```

## Step 2: Set Up Git Repository

```bash
# Set up a workspace repository for the index
cd git-repos/index-workspace
git init

# Add the essential config.json file
cat > config.json << EOF
{
  "dl": "http://localhost:8855/api/v1/crates",
  "api": "http://localhost:8855",
  "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

# Commit the config file
git add config.json
git commit -m "Add config.json"

# Configure git tracking
git config branch.master.remote origin
git config branch.master.merge refs/heads/master

cd ../..
```

## Step 3: Start PostgreSQL

```bash
# Create docker-compose.yml
cat > docker-compose.yml << EOF
version: '3.8'
services:
  postgres:
    image: postgres:14.4
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: meuse
      POSTGRES_USER: meuse
      POSTGRES_PASSWORD: meuse
    volumes:
      - pg_data:/var/lib/postgresql/data
volumes:
  pg_data:
EOF

# Start PostgreSQL
docker compose up -d postgres
```

## Step 4: Configure Meuse

```bash
# Create configuration directory
mkdir -p config

# Create configuration file with initial users
cat > config/init_users_config.yaml << EOF
database:
  user: "meuse"
  password: "meuse"
  host: "localhost"
  port: 5432
  name: "meuse"
  max-pool-size: 10

http:
  address: "0.0.0.0"
  port: 8855

logging:
  level: "info"
  console:
    encoder: "json"
  overrides:
    org.eclipse.jetty: "info"
    com.zaxxer.hikari.pool.HikariPool: "info"
    org.apache.http: "error"
    io.netty.buffer.PoolThreadCache: "error"
    org.eclipse.jgit.internal.storage.file.FileSnapshot: "info"
    com.amazonaws.auth.AWS4Signer: "warn"
    com.amazonaws.retry.ClockSkewAdjuster: "warn"
    com.amazonaws.request: "warn"
    com.amazonaws.requestId: "warn"

metadata:
  type: "shell"
  path: "$(pwd)/git-repos/index-workspace"
  target: "origin/master"
  url: "http://localhost:8855/index"

crate:
  store: "filesystem"
  path: "./crates"

frontend:
  enabled: true
  public: true
  secret: "change-this-to-a-random-32-char-string"

# Initial users configuration
init-users:
  users:
    - name: "admin"
      password: "admin_password"
      description: "Administrator user"
      role: "admin"
      active: true
    - name: "tech_user"
      password: "tech_password"
      description: "Tech user with publish rights"
      role: "tech"
    - name: "reader"
      password: "reader_password"
      description: "Read-only user"
      role: "read-only"
EOF
```

## Step 5: Start Meuse

```bash
# Start Meuse using the configuration
export MEUSE_CONFIGURATION=config/init_users_config.yaml
lein run
```

## Step 6: Configure Cargo

```bash
# Configure Cargo to use Meuse
mkdir -p ~/.cargo

# Add registry to config.toml
cat >> ~/.cargo/config.toml << EOF
[registries.meuse]
index = "file://$(pwd)/git-repos/index-workspace"
EOF

# Create a token using the admin credentials
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"name":"admin_token","validity":365,"user":"admin","password":"admin_password"}' \
  http://localhost:8855/api/v1/meuse/token | grep -o '"token":"[^"]*"' | cut -d '"' -f 4)

# Add token to credentials.toml
cat >> ~/.cargo/credentials.toml << EOF
[registries.meuse]
token = "$TOKEN"
EOF

echo "Token added to credentials: $TOKEN"
```

## Step 7: Publishing a Crate

```bash
# Create a library crate
cargo new --lib my_crate
cd my_crate

# Edit Cargo.toml to include:
# [package.metadata.registry]
# publish = ["meuse"]

# Publish to Meuse
cargo publish --registry meuse
```

## Step 8: Using Published Crates

In your other projects' `Cargo.toml`:

```toml
[dependencies]
my_crate = { version = "0.1.0", registry = "meuse" }
```

## Troubleshooting

### Common Issues

1. **Git Repository Issues**
    - Ensure `config.json` exists in the root of the workspace repo
    - Check that git config has proper tracking set up

2. **Path Configuration**
    - Always use absolute paths in Meuse configuration
    - Double-check repository paths match between Cargo and Meuse configs

3. **Library Crates**
    - Ensure crates have a `lib.rs` file with public functions to be usable as dependencies

4. **Database Connectivity**
    - Verify PostgreSQL is running and accessible
    - Ensure database credentials match between Docker and Meuse config

### Logs and Debugging

If you encounter issues, check:

- Meuse server logs for detailed error information
- Git repository state and configuration
- Database connectivity and tables
- Token authentication validity

## Cleanup

To clean up your environment:

```bash
# Stop Meuse (press Ctrl+C if running in foreground)

# Stop and remove PostgreSQL
docker compose down -v

# Remove generated directories if needed
rm -rf index crates git-repos
```

For more detailed configuration options, see the [Configuration](/installation/configuration) section.
