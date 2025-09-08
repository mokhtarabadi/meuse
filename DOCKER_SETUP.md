# Meuse Docker Deployment Guide

This guide covers deploying Meuse (a private Rust registry) using Docker Compose with Nginx reverse proxy and Cloudflare
SSL termination.

## 🐳 Docker Image

This deployment uses the official Meuse Docker image:

- **Docker Hub:** https://hub.docker.com/r/mokhtarabadi/meuse
- **Latest:** `mokhtarabadi/meuse:latest`
- **Version 1.3.0:** `mokhtarabadi/meuse:1.3.0`

The image includes:

- ✅ Meuse application (Rust registry server)
- ✅ Java 17 runtime environment
- ✅ Git for index management
- ✅ Health check endpoints
- ✅ Optimized for production use

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [Git Index Repository Setup](#git-index-repository-setup)
4. [Configuration](#configuration)
5. [Deployment](#deployment)
6. [Root User Creation](#root-user-creation)
7. [Cloudflare SSL Setup](#cloudflare-ssl-setup)
8. [Cargo Configuration](#cargo-configuration)
9. [Usage Examples](#usage-examples)
10. [Troubleshooting](#troubleshooting)
11. [Managing Self-Hosted Repository](#managing-self-hosted-repository)

## Prerequisites

- Docker and Docker Compose installed
- A domain name pointing to your server
- Cloudflare account (for SSL termination)
- Git installed locally
- Basic knowledge of Rust/Cargo

## Initial Setup

### 1. Clone and Prepare the Repository

```bash
git clone https://github.com/mokhtarabadi/meuse.git
cd meuse
```

### 2. Create Environment Configuration

```bash
cp .env.example .env
```

Edit `.env` file with your values:

```bash
# Generate a secure PostgreSQL password
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Generate a secure frontend secret
MEUSE_FRONTEND_SECRET=$(openssl rand -base64 32)

# Set your domain
DOMAIN=registry.yourdomain.com
```

### 3. Create Required Directories

```bash
mkdir -p logs/nginx
mkdir -p config
```

## Git Index Repository Setup

Meuse requires a Git repository to store crate metadata. You have three options:

### Option 1: Self-Hosted Private Git Repository (Recommended)

**Fully private solution with no external dependencies**

This option creates a private Git repository on your server that is served via HTTP/HTTPS. Your crate metadata never
leaves your server.

**Benefits:**

- ✅ Completely private - no metadata exposed externally
- ✅ No dependency on external services like GitHub
- ✅ Full control over your data
- ✅ Standard Git protocol support
- ✅ Works with all Cargo clients

**How it works:**

1. Creates a local Git repository with your crate index
2. Sets up a bare Git repository for HTTP access
3. Configures nginx with `git-http-backend` to serve the repository
4. Uses `fcgiwrap` to handle Git HTTP protocol

**Automatic Setup:**
The install script automatically configures everything when you choose Option 3.

### Option 2: GitHub Fork (Public Metadata)

**⚠️ Warning: This makes your crate metadata public**

### 1. Fork crates.io-index

Go to https://github.com/rust-lang/crates.io-index and fork it to your GitHub account.

### 2. Clone Your Fork

```bash
# Clone to a temporary location to initialize
git clone https://github.com/YOUR_USERNAME/crates.io-index.git temp-index
cd temp-index
```

### 3. Configure the Index

Edit `config.json` in the repository root:

```json
{
    "dl": "https://registry.yourdomain.com/api/v1/crates",
    "api": "https://registry.yourdomain.com",
    "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
```

Commit and push the changes:

```bash
git add config.json
git commit -m "Configure registry URLs for Meuse"
git push origin master
```

### 4. Update Meuse Configuration

Edit `config/config.yaml` and update the metadata URL:

```yaml
metadata:
  type: "shell"
  path: "/app/index"
  target: "origin/master"
  url: "https://github.com/YOUR_USERNAME/crates.io-index"
```

## Configuration

The main configuration is in `config/config.yaml`. Key sections to review:

### Database Configuration

```yaml
database:
  user: "meuse"
  password: !envsecret "POSTGRES_PASSWORD"
  host: "postgres"
  port: 5432
  name: "meuse"
```

### HTTP Configuration

```yaml
http:
  address: "0.0.0.0"
  port: 8855
```

### Storage Configuration

**Filesystem Storage (Default):**

```yaml
crate:
  store: "filesystem"
  path: "/app/crates"
```

**S3 Storage (Optional):**

```yaml
crate:
  store: "s3"
  access-key: !envsecret "S3_ACCESS_KEY"
  secret-key: !envsecret "S3_SECRET_KEY"
  endpoint: "s3.amazonaws.com"
  bucket: "your-crate-bucket"
```

## Deployment

### 1. Build and Start Services

```bash
# Build and start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f meuse
docker-compose logs -f nginx
docker-compose logs -f postgres
```

### 2. Verify Health

```bash
# Check health endpoints
curl http://localhost/healthz
curl http://localhost:8855/healthz
```

## Root User Creation

Meuse requires an initial admin user. Create it via direct database insertion:

### 1. Generate Password Hash

```bash
# Generate password hash using the Meuse jar
docker-compose exec meuse java -jar /app/meuse.jar password your_secure_password
```

Copy the generated bcrypt hash.

### 2. Insert Root User

```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U meuse -d meuse

# Insert the root user (replace the password hash with your generated one)
INSERT INTO users(id, name, password, description, active, role_id)
VALUES ('f3e6888e-97f9-11e9-ae4e-ef296f05cd17', 'admin', '$2a$11$GENERATED_HASH_HERE', 'Administrator user', true, '867428a0-69ba-11e9-a674-9f6c32022150');

# Exit psql
\q
```

### 3. Create API Token

Use the API to create a token for the root user:

```bash
curl --header "Content-Type: application/json" --request POST \
--data '{"name":"admin_token","validity":365,"user":"admin","password":"your_secure_password"}' \
http://localhost/api/v1/meuse/token
```

Save the returned token for later use.

## Cloudflare SSL Setup

### 1. Cloudflare Configuration

1. Add your domain to Cloudflare
2. Set DNS A record pointing to your server IP
3. Set SSL/TLS mode to "Full" (not "Full (strict)" since we're using HTTP internally)
4. Enable "Always Use HTTPS"

### 2. Cloudflare Page Rules (Optional)

Add page rules for better caching:

```
registry.yourdomain.com/api/v1/crates/*/download
- Browser Cache TTL: 1 month
- Cache Level: Standard

registry.yourdomain.com/api/v1/mirror/*
- Browser Cache TTL: 1 month  
- Cache Level: Standard
```

### 3. Update Nginx Configuration (Optional)

For production, you might want to redirect HTTP to HTTPS and add real IP detection:

```nginx
# Add to your nginx.conf server block
# Real IP detection for Cloudflare
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;
real_ip_header CF-Connecting-IP;
```

## Cargo Configuration

### For Self-Hosted Private Git Repository

Add to `~/.cargo/config.toml`:

```toml
[registries.myregistry]
index = "https://your-domain.com/git/index.git"

# Optional: Make your registry the default
[source.crates-io]
replace-with = "myregistry"

[source.myregistry]
registry = "https://your-domain.com/git/index.git"
```

### For GitHub Fork

### 1. Registry Configuration

Add to `~/.cargo/config.toml`:

```toml
[registries.myregistry]
index = "https://github.com/YOUR_USERNAME/crates.io-index"

# Optional: Make your registry the default
[source.crates-io]
replace-with = "myregistry"

[source.myregistry]
registry = "https://github.com/YOUR_USERNAME/crates.io-index"
```

## Usage Examples

### Publishing a Crate

```bash
# In your Rust project directory
cargo publish --registry myregistry
```

### Using Crates from Your Registry

In your `Cargo.toml`:

```toml
[dependencies]
my-private-crate = { version = "1.0", registry = "myregistry" }
```

### Managing Users and Tokens

```bash
# Create a new user (admin only)
curl --header "Content-Type: application/json" --request POST \
-H "Authorization: YOUR_TOKEN" \
--data '{"active":true,"description":"CI user","name":"ci-user","password":"secure_password","role":"tech"}' \
https://registry.yourdomain.com/api/v1/meuse/user

# Create a token for a user
curl --header "Content-Type: application/json" --request POST \
--data '{"name":"ci_token","validity":90,"user":"ci-user","password":"secure_password"}' \
https://registry.yourdomain.com/api/v1/meuse/token

# List crates
curl --header "Content-Type: application/json" \
-H "Authorization: YOUR_TOKEN" \
https://registry.yourdomain.com/api/v1/meuse/crate
```

### Setting up Mirroring

To use Meuse as a crates.io mirror:

1. Configure `~/.cargo/config.toml`:

```toml
[source.crates-io]
replace-with = "mirror"

[source.mirror]
registry = "https://github.com/YOUR_USERNAME/crates.io-index"
```

2. Crates will be automatically downloaded from crates.io and cached on first use.

## Troubleshooting

### Common Issues

**1. "Connection refused" errors**

- Check if services are running: `docker-compose ps`
- Check logs: `docker-compose logs meuse`
- Verify health endpoints: `curl http://localhost/healthz`

**2. Database connection issues**

- Ensure PostgreSQL is healthy: `docker-compose logs postgres`
- Check environment variables in `.env`
- Verify database credentials in config

**3. Git index issues**

- Ensure the index repository is properly cloned: `docker-compose exec meuse ls -la /app/index`
- Check git credentials and permissions
- Verify the repository URL in config

**4. Permission denied errors**

- Check Docker volume permissions
- Ensure the meuse user can write to mounted directories

### Logs and Debugging

```bash
# Application logs
docker-compose logs -f meuse

# Database logs  
docker-compose logs -f postgres

# Nginx logs
docker-compose logs -f nginx

# Access nginx logs directly
tail -f logs/nginx/access.log
tail -f logs/nginx/error.log

# Enter container for debugging
docker-compose exec meuse bash
docker-compose exec postgres psql -U meuse -d meuse
```

### Performance Tuning

For production deployments:

1. **PostgreSQL tuning** in `docker-compose.yml`:

```yaml
postgres:
  command: >
    postgres
    -c shared_buffers=256MB
    -c max_connections=100
    -c effective_cache_size=512MB
```

2. **Nginx worker processes** in `nginx.conf`:

```nginx
worker_processes auto;
worker_connections 2048;
```

3. **Database connection pooling** in `config/config.yaml`:

```yaml
database:
  max-pool-size: 20
```

### Backup and Recovery

**Backup:**

```bash
# Database backup
docker-compose exec postgres pg_dump -U meuse meuse > backup.sql

# Crate files backup (if using filesystem storage)
tar -czf crates-backup.tar.gz -C data crates/

# Git index backup
tar -czf index-backup.tar.gz -C data index/
```

**Recovery:**

```bash
# Restore database
docker-compose exec -T postgres psql -U meuse meuse < backup.sql

# Restore crate files
tar -xzf crates-backup.tar.gz -C data/

# Restore git index
tar -xzf index-backup.tar.gz -C data/
```

## Managing Self-Hosted Repository

### Understanding the Self-Hosted Setup

When you choose the self-hosted Git option, the installer creates:

1. **Working Repository** (`./index/`): Where Meuse manages crate metadata
2. **Bare Repository** (`./git-repos/index.git/`): HTTP-accessible repository for Cargo clients
3. **Git HTTP Backend**: nginx + fcgiwrap serving the bare repository

### Repository Structure

```
meuse-registry/
├── index/                    # Working Git repository (Meuse writes here)
│   ├── config.json          # Registry configuration
│   ├── 1/, 2/, 3/           # Crate index directories
│   └── ab/cd/               # Crate metadata files
├── git-repos/               # Bare repositories for HTTP access
│   └── index.git/           # Bare repository served via HTTP
└── docker-compose.yml       # Includes fcgiwrap service
```

### Manual Repository Operations

**View repository status:**

```bash
cd meuse-registry/index
git status
git log --oneline -10
```

**Sync working repository to bare repository:**

```bash
cd meuse-registry
git --git-dir=git-repos/index.git --work-tree=index fetch origin master:master
```

**Backup the repository:**

```bash
# Backup working repository
tar -czf index-backup-$(date +%Y%m%d).tar.gz index/

# Backup bare repository  
tar -czf bare-repo-backup-$(date +%Y%m%d).tar.gz git-repos/
```

### Troubleshooting Self-Hosted Git Issues

**1. "Repository not accessible" errors**

Check fcgiwrap service status:

```bash
docker compose logs fcgiwrap
docker compose ps fcgiwrap
```

**2. Git HTTP backend not working**

Test the Git HTTP endpoint:

```bash
curl -I https://your-domain.com/git/index.git/info/refs?service=git-upload-pack
```

Expected response should include:

```
HTTP/2 200
Content-Type: application/x-git-upload-pack-advertisement
```

**3. Permission issues**

Fix repository permissions:

```bash
# Fix working repository permissions
sudo chown -R $(whoami):$(whoami) index/
chmod -R 755 index/

# Fix bare repository permissions  
sudo chown -R $(whoami):$(whoami) git-repos/
chmod -R 755 git-repos/
```

**4. fcgiwrap socket issues**

Restart the fcgiwrap service:

```bash
docker compose restart fcgiwrap nginx
```

### Git Repository Maintenance

**Clean up repository:**

```bash
cd index
git gc --prune=now
git repack -ad
```

**Verify repository integrity:**

```bash
cd index  
git fsck --full
```

**Update bare repository from working repository:**

```bash
cd index
git push ../git-repos/index.git master
```

## Security Considerations

1. **Change default passwords** in `.env`
2. **Use strong tokens** for API access
3. **Enable rate limiting** in nginx (already configured)
4. **Regular backups** of database and crate files
5. **Monitor access logs** for suspicious activity
6. **Keep Docker images updated**
7. **Use HTTPS only** in production (via Cloudflare)
8. **Restrict database access** to localhost only

## Production Deployment Checklist

- [ ] Domain configured and pointing to server
- [ ] Cloudflare SSL configured
- [ ] Environment variables set securely
- [ ] Git index repository forked and configured
- [ ] Root user created
- [ ] API tokens generated
- [ ] Cargo configuration tested
- [ ] Backup strategy implemented
- [ ] Monitoring and alerting configured
- [ ] Security hardening applied

For additional help, consult the [official Meuse documentation](https://meuse.mcorbin.fr/) or open an issue on
the [GitHub repository](https://github.com/mokhtarabadi/meuse).