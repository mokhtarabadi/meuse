## Using the Registry

### Configure Cargo

Add to `~/.cargo/config.toml`:

```toml
[registries.meuse]
index = "http://localhost:8180/myindex"

[net]
git-fetch-with-cli = true  # Required for HTTP authentication
```

### Create Authentication Token

```bash
# Using the API (replace with your admin credentials)
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"my_token","validity":365,"user":"admin","password":"admin_production_password_2024"}' \
  http://localhost:8855/api/v1/meuse/token
```

Add the token to `~/.cargo/credentials.toml`:

```toml
[registries.meuse]
token = "your-token-here"
```

### Publish a Crate

```bash
# In your Rust project
cargo publish --registry meuse
```

---
title: Docker Deployment
weight: 25
disableToc: false
---

# Docker Deployment

This guide explains how to deploy Meuse using Docker Compose with automatic initialization. The setup includes PostgreSQL, Git HTTP server, and the Meuse application, all configured to work together seamlessly.

## Prerequisites

- Docker and Docker Compose installed
- Basic understanding of Docker concepts

## Quick Start

### Step 1: Clone and Configure

```bash
# Clone the repository
git clone https://github.com/mcorbin/meuse.git
cd meuse

# Copy environment configuration
cp .env.example .env
```

### Step 2: Configure Environment

Edit the `.env` file to customize your deployment:

```bash
# Edit with your preferred editor
nano .env  # or vim, code, etc.
```

Key settings to review:

- `DOMAIN`: Your domain name (default: localhost)
- `REGISTRY_URL`: The Meuse registry URL
- `CARGO_API_URL`: The Cargo API endpoint
- `GIT_USER` and `GIT_PASSWORD`: Git HTTP authentication credentials
- Database passwords and other security settings

### Step 3: Generate Git Authentication

Before starting the services, generate the htpasswd file for Git HTTP authentication:

```bash
./scripts/gen-htpasswd.sh
```

This script will:

- Read credentials from your `.env` file
- Generate an htpasswd file for nginx authentication
- Store it in `git-data/htpasswd`

### Step 4: Start Services

```bash
docker compose up -d
```

On first run, the Meuse container will automatically:

- Initialize a non-bare Git repository at `/app/git-data/myindex`
- Create the required `config.json` with your registry URLs
- Set up proper permissions
- Create the crates storage directory

### Step 5: Verify Deployment

```bash
# Check all services are running
docker compose ps

# Check Meuse logs for initialization
docker compose logs meuse

# Test the health endpoint
curl http://localhost:8855/healthz
```

You should see three healthy services:

- `meuse-postgres` - PostgreSQL database
- `meuse-git-server` - Git HTTP server
- `meuse-app` - The Meuse application

## Manual Setup (Advanced)

If you prefer manual initialization without the automatic setup:

1. Set environment variable before starting:
   ```bash
   export SKIP_GIT_INIT=true
   docker compose up -d
   ```

2. Manually initialize the Git repository as needed

## How It Works

### Automatic Initialization

The Meuse container uses an entrypoint script that:

1. **Checks for existing setup**: On startup, it checks if `/app/git-data/myindex` exists
2. **Initializes if needed**: If not found, it automatically:
    - Creates a non-bare Git repository
    - Generates `config.json` using environment variables
    - Commits the configuration to the repository
    - Sets proper permissions for the meuse user
3. **Skips if exists**: On subsequent restarts, initialization is skipped

This means you can destroy and recreate containers without losing data (volumes persist), and new deployments
automatically set themselves up.

## Configuration

### Environment Variables

The deployment is configured entirely through environment variables in `.env`:

#### Core Configuration

- `DOMAIN`: Your domain name
- `REGISTRY_URL`: Full URL to your Meuse instance
- `CARGO_API_URL`: API endpoint for Cargo

#### Service Ports

- `MEUSE_PORT`: Meuse HTTP port (default: 8855)
- `GIT_PORT`: Git HTTP server port (default: 8180)
- `POSTGRES_PORT`: PostgreSQL port (default: 5432)

#### Authentication

- `GIT_USER` / `GIT_PASSWORD`: Git HTTP authentication
- `ADMIN_USER` / `ADMIN_PASSWORD`: Initial admin user
- `TECH_USER` / `TECH_PASSWORD`: Technical user for CI/CD
- `READ_USER` / `READ_PASSWORD`: Read-only user

#### Storage

- Crate files: Docker volume `meuse_crates`
- Git data: Docker volume `meuse_git_data`
- PostgreSQL: Docker volume `pg_data`

## Volume Management

Data persistence is handled through Docker volumes:

- `meuse_git_data`: Git repositories and htpasswd
- `meuse_crates`: Crate binary files
- `pg_data`: PostgreSQL database

To backup:

```bash
docker run --rm -v meuse_git_data:/data -v $(pwd):/backup alpine tar czf /backup/git-data-backup.tar.gz -C /data .
docker run --rm -v meuse_crates:/data -v $(pwd):/backup alpine tar czf /backup/crates-backup.tar.gz -C /data .
```

## Production Considerations

1. **Use strong passwords**: Update all default passwords in `.env`
2. **Enable HTTPS**: Use a reverse proxy with SSL termination
3. **Regular backups**: Implement automated backup of volumes
4. **Monitor services**: Set up monitoring for all components
5. **Resource limits**: Add resource constraints to docker-compose.yml

## Troubleshooting

### Git Repository Not Initializing

Check the Meuse container logs:

```bash
docker compose logs meuse | grep INIT
```

### Authentication Issues

1. Regenerate htpasswd:
   ```bash
   ./scripts/gen-htpasswd.sh
   docker compose restart git-server
   ```

2. Verify Git server access:
   ```bash
   git clone http://gituser@localhost:8180/myindex.git test-repo
   ```

### Database Connection Errors

1. Check PostgreSQL is running:
   ```bash
   docker compose ps postgres
   ```

2. Test connection:
   ```bash
   docker compose exec postgres psql -U meuse -d meuse -c "SELECT 1"
   ```

### Bare Repository Error

If you encounter errors like:
`org.eclipse.jgit.errors.NoWorkTreeException: Bare Repository has neither a working tree, nor an index`
This means the repo was created as bare. To fix, re-initialize without the '--bare' flag (use just `git init`) and
ensure your deployment points 'myindex' rather than 'myindex.git'. See entrypoint.sh for details.

## Upgrading

To upgrade Meuse:

```bash
# Pull latest changes
git pull

# Update container image
docker compose pull meuse

# Restart with new version
docker compose up -d
```

The automatic initialization will be skipped if the Git repository already exists, preserving your data.