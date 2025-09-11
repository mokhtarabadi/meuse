---
title: Quick Start Guide
weight: 15
disableToc: false
---

# Setting Up Meuse: Quick Start Guide

This guide provides two approaches to set up Meuse: a streamlined Docker approach with automatic initialization, or a
manual setup for more control.

## Prerequisites

Choose your setup method:

**For Docker Setup (Recommended)**:

- Docker and Docker Compose
- Git

**For Manual Setup**:
- Java (OpenJDK 11+)
- PostgreSQL
- Git
- Cargo/Rust toolchain

## Option 1: Docker Setup (Recommended)

The fastest way to get Meuse running:

```bash
# Clone the repository
git clone https://github.com/mcorbin/meuse.git
cd meuse

# Configure environment
cp .env.example .env
# Edit .env to customize settings (optional)

# Generate Git authentication
./scripts/gen-htpasswd.sh

# Start everything
docker compose up -d
```

That's it! The Meuse container automatically initializes the Git repository on first run.

To verify:

```bash
docker compose ps  # Check all services are running
curl http://localhost:8855/healthz  # Test Meuse health
```

See the [Docker Deployment](/installation/docker-deployment) guide for detailed configuration options.

## Option 2: Manual Setup

If you prefer to run Meuse directly without Docker:

### Step 1: Set Up PostgreSQL

```bash
# Using Docker for PostgreSQL only
docker run -d --name meuse-postgres \
  -e POSTGRES_DB=meuse \
  -e POSTGRES_USER=meuse \
  -e POSTGRES_PASSWORD=meuse \
  -p 5432:5432 \
  postgres:14.4
```

Or install PostgreSQL locally and create the database.

### Step 2: Prepare Git Repository

```bash
# Create directories
mkdir -p git-repos/index-workspace crates

# Set up Git repository
cd git-repos/index-workspace
git init

# Create config.json
cat > config.json << EOF
{
  "dl": "http://localhost:8855/api/v1/crates",
  "api": "http://localhost:8855",
  "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

# Commit configuration
git add config.json
git commit -m "Add config.json"

# Configure Git
git config branch.master.remote origin
git config branch.master.merge refs/heads/master

cd ../..
```

### Step 3: Configure Meuse

Create `config/config.yaml`:

```yaml
database:
  user: "meuse"
  password: "meuse"
  host: "localhost"
  port: 5432
  name: "meuse"

http:
  address: "0.0.0.0"
  port: 8855

logging:
  level: "info"

metadata:
  type: "shell"
  path: "./git-repos/index-workspace"
  target: "origin/master"
  url: "http://localhost:8855/index"

crate:
  store: "filesystem"
  path: "./crates"

frontend:
  enabled: true
  public: true

# Initial admin user
init-users:
  users:
    - name: "admin"
      password: "admin_password"
      description: "Administrator"
      role: "admin"
```

### Step 4: Run Meuse

```bash
# Download the latest release from GitHub
wget https://github.com/mcorbin/meuse/releases/latest/download/meuse.jar

# Or build from source
lein uberjar

# Run Meuse
export MEUSE_CONFIGURATION=config/config.yaml
java -jar meuse.jar
```

## Configure Cargo Client

Regardless of setup method, configure Cargo to use your registry:

### 1. Add Registry to Cargo

Edit `~/.cargo/config.toml`:

```toml
[registries.meuse]
# For Docker setup with Git server
index = "http://localhost:8180/myindex.git"

# For manual setup
# index = "file:///path/to/git-repos/index-workspace"

[net]
git-fetch-with-cli = true  # Required for HTTP Git
```

### 2. Create Authentication Token

```bash
# Create a token via API
TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
  -d '{"name":"my_token","validity":365,"user":"admin","password":"admin_password"}' \
  http://localhost:8855/api/v1/meuse/token | jq -r .token)

echo "Token: $TOKEN"
```

### 3. Add Token to Credentials

Edit `~/.cargo/credentials.toml`:

```toml
[registries.meuse]
token = "your-token-here"
```

## Publishing Your First Crate

```bash
# Create a test library
cargo new --lib my-first-crate
cd my-first-crate

# Add registry metadata to Cargo.toml
cat >> Cargo.toml << EOF

[package.metadata.registry]
publish = ["meuse"]
EOF

# Publish to Meuse
cargo publish --registry meuse
```

## Using Published Crates

In another project's `Cargo.toml`:

```toml
[dependencies]
my-first-crate = { version = "0.1.0", registry = "meuse" }
```

## Next Steps

- **Security**: Change default passwords in production
- **HTTPS**: Set up SSL/TLS for secure connections
- **Monitoring**: Enable Prometheus metrics at `/metrics`
- **Backup**: Regular backups of database and crate storage

## Troubleshooting

### Docker Issues

```bash
# View logs
docker compose logs -f meuse

# Restart services
docker compose restart

# Reset everything (WARNING: deletes data)
docker compose down -v
```

### Manual Setup Issues

- **Database connection**: Verify PostgreSQL is running and credentials match
- **Git issues**: Ensure Git repository has proper permissions
- **Port conflicts**: Check ports 8855 (Meuse) and 8180 (Git) are available

For more help, see the [complete documentation](/installation).
