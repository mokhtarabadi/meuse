---
title: Git HTTP Backend (nginx + htpasswd)
weight: 20
disableToc: false
---

# Git HTTP Backend Server for Meuse

This document explains how to run and configure a lightweight Git HTTP server using nginx and git-http-backend with
basic authentication. This is an optimal solution for hosting your Cargo index repository when running a private Meuse
registry.

## Overview

The Git HTTP backend solution:

- Uses nginx with git-http-backend CGI script
- Provides HTTP basic authentication via htpasswd
- Requires minimal resources compared to full Git servers
- Supports the Git smart HTTP protocol (git clone/push over HTTP)
- Works with Cargo's registry index requirements

## Getting Started

### Prerequisites

- Docker and Docker Compose
- The Meuse repository cloned locally

### Configuration Files

- `docker-compose.yml` — Contains the git-server service definition
- `docker/git/default.conf` — Nginx configuration with git-http-backend setup
- `scripts/gen-htpasswd.sh` — Helper script to generate authentication credentials
- `.env.example` — Example environment variables file (copy to `.env`)

## Quick Start with Docker Compose

The simplest way to use the Git HTTP backend is with the provided Docker Compose setup:

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env to set GIT_USER and GIT_PASSWORD

# 2. Generate authentication file
./scripts/gen-htpasswd.sh

# 3. Start services
docker compose up -d

# 4. Verify
git clone http://gituser@localhost:8180/myindex.git test-clone
```

The Meuse container will automatically initialize the Git repository on first run.

## Manual Git Server Setup

If you want to run the Git server separately:

### Prerequisites

- Docker
- The htpasswd file must be generated first

### Step 1: Generate Authentication

```bash
# Create git-data directory
mkdir -p git-data

# Option 1: Use the provided script
./scripts/gen-htpasswd.sh

# Option 2: Generate manually
docker run --rm \
  -v "$(pwd)/git-data:/git-data" \
  httpd:2.4-alpine \
  htpasswd -bc /git-data/htpasswd username password
```

### Step 2: Initialize Git Repository

The Meuse container handles this automatically, but for manual setup:

```bash
# Create non-bare repository
mkdir -p git-data/myindex.git
cd git-data/myindex.git
git init

# Create config.json
cat > config.json << EOF
{
  "dl": "http://localhost:8855/api/v1/crates",
  "api": "http://localhost:8855",
  "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

# Add to repository
git add config.json
git commit -m "Initialize registry"
git update-server-info
cd ../..
```

### Step 3: Run Git Server

Using Docker Compose (recommended):

```bash
docker compose up -d git-server
```

Or standalone:

```bash
docker run -d \
  --name meuse-git-server \
  -p 8180:80 \
  -v $(pwd)/git-data:/srv/git \
  -v $(pwd)/git-data/htpasswd:/etc/nginx/.htpasswd:ro \
  -v $(pwd)/docker/git/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/docker/git/default.conf:/etc/nginx/conf.d/default.conf:ro \
  emarcs/nginx-git:latest
```

## Integrating with Meuse

### Configure Meuse to use the Git HTTP server

Update your Meuse configuration (e.g., `config/init_users_config.yaml`) to use the Git HTTP server:

```yaml
metadata:
  type: "shell"
  path: "/absolute/path/to/meuse/git-data/myindex.git"
  target: "origin/master"
  url: "http://localhost:8180/myindex.git"
```

Note the important settings:

- `path`: Absolute path to the local git repository
- `target`: For a non-bare repo, use "origin/master". (Bare repos are NOT supported with Meuse)
- `url`: The HTTP URL of your git server (what Cargo clients will use)

### Starting Both Services

To start both PostgreSQL and the Git HTTP server:

```bash
docker compose up -d postgres git-server
```

### Start Meuse

```bash
export MEUSE_CONFIGURATION=config/init_users_config.yaml
lein run
```

## Client Setup

### Configure Cargo

1. **Create API token**

   Generate a token using Meuse API (replace with actual admin credentials):

   ```bash
   curl -s -X POST -H "Content-Type: application/json" \
     -d '{"name":"admin_token","validity":365,"user":"admin","password":"admin_password"}' \
     http://localhost:8855/api/v1/meuse/token
   ```

2. **Configure Cargo credentials**

   In `~/.cargo/credentials.toml`:

   ```toml
   [registries.meuse]
   token = "your-token-from-api-response"
   ```

3. **Configure Cargo registry**

   In `~/.cargo/config.toml`:

   ```toml
   [registries.meuse]
   index = "http://localhost:8180/myindex.git"
   
   # Enable git-fetch-with-cli for HTTP authentication
   [net]
   git-fetch-with-cli = true
   ```

### Publishing Crates

1. **Create a crate**

   ```bash
   cargo new --lib my-crate
   cd my-crate
   ```

2. **Update Cargo.toml**

   ```toml
   [package]
   name = "my-crate"
   version = "0.1.0"
   edition = "2021"
   description = "My private crate"
   license = "MIT"
   
   [dependencies]
   
   [package.metadata.registry]
   publish = ["meuse"]
   ```

3. **Publish the crate**

   ```bash
   cargo publish --registry meuse
   ```

### Using Published Crates

In another project's `Cargo.toml`:

```toml
[dependencies]
my-crate = { version = "0.1.0", registry = "meuse" }
```

## Troubleshooting

### Common Issues

#### Authentication Problems

- **Symptom**: 401 Unauthorized when cloning or pushing
- **Solution**: Regenerate htpasswd file and restart git-server
  ```bash
  rm -rf git-data/htpasswd
  ./scripts/gen-htpasswd.sh
  docker compose restart git-server
  ```

#### 404 Not Found for Git Protocol URLs

- **Symptom**: 404 errors when accessing `info/refs?service=git-upload-pack`
- **Solution**: Ensure git update-server-info was run and restart the server
  ```bash
  docker compose exec git-server bash -c 'cd /srv/git/myindex.git && git update-server-info'
  docker compose restart git-server
  ```

#### Cargo Authentication Issues

- **Symptom**: Cargo cannot fetch index or publish crates
- **Solution**: Enable git-fetch-with-cli in Cargo config
  ```toml
  [net]
  git-fetch-with-cli = true
  ```

#### Git Server Not Starting

- **Symptom**: git-server container fails to start
- **Solution**: Check logs and verify the nginx configuration
  ```bash
  docker compose logs git-server
  ```

#### Cannot Push to Repository

- **Symptom**: Git push operations fail with "not found" or permission errors
- **Solution**: Check repository permissions and nginx configuration
  ```bash
  docker compose exec git-server ls -la /srv/git/myindex.git
  ```

#### Bare Repository Error

- **Symptom**: `org.eclipse.jgit.errors.NoWorkTreeException: Bare Repository has neither a working tree, nor an index`
- **Solution**: You have a bare repo. Fix it by re-initializing with `git init` (no '--bare'). All Meuse operational
  features require a working tree.

### Debugging

- **Check nginx logs**:
  ```bash
  docker compose exec git-server cat /var/log/nginx/error.log
  ```

- **Test git-http-backend with curl**:
  ```bash
  docker compose exec git-server curl -u username:password http://localhost/myindex.git/info/refs?service=git-upload-pack
  ```

- **Enable verbose Git output**:
  ```bash
  GIT_CURL_VERBOSE=1 git clone http://username:password@localhost:8180/myindex.git
  ```

## Security Considerations

### Production Recommendations

1. **Use HTTPS**: Add TLS termination using either:
    - A reverse proxy in front of the git-server
    - Configuring nginx with SSL certificates

2. **Credential Management**:
    - Use dedicated service accounts with restricted permissions
    - Rotate credentials regularly
    - Consider using deploy tokens for CI/CD pipelines

3. **Monitoring**:
    - Monitor failed authentication attempts
    - Set up rate limiting for auth endpoints

4. **Backup Strategy**:
    - Regularly backup the git-data directory
    - Ensure backups are secured appropriately

## Advanced Configuration

### Custom nginx Configuration

The default nginx configuration is mounted from `docker/git/default.conf`. You can customize this file to add features
like:

- TLS/HTTPS support
- Additional security headers
- Rate limiting
- Access control

### Multiple Repositories

You can host multiple Git repositories by creating additional non-bare repos in the `git-data` directory:

```bash
cd git-data
git init another-repo
```

They will be automatically accessible via `http://localhost:8180/another-repo.git`.

## Summary

The Git HTTP backend with nginx provides a lightweight and effective solution for hosting your Cargo index repository.
It offers:

- Simple authentication via htpasswd
- Easy integration with Meuse
- Low resource usage
- Compatibility with Cargo and Git clients

For most private registry use cases, this solution is sufficient and more efficient than running a full-featured Git
server.
