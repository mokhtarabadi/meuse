# Meuse - A Private Rust Crate Registry

A free crate registry for the Rust programming language that implements
the [alternative registries](https://github.com/rust-lang/rfcs/blob/master/text/2141-alternative-registries.md) RFC. Use
Meuse to store your private crates, configure it to mirror crates.io, and leverage local Git support for more
flexibility.

## Features

- Complete implementation of the alternative registries RFC (including search)
- Crates.io mirroring
- Multiple backends for crates files: filesystem, S3
- Multiple ways of managing the Git crate Index: git command, JGit
- Fixed Git container permissions and ownership issues
- Environment variable configuration support
- Production-ready multi-stage Docker builds
- Manage categories, users, roles, and tokens
- Manage crates
- Security: HTTPS support, TLS support for the PostgreSQL client
- Monitoring: Meuse exposes a Prometheus endpoint with various metrics
- Small frontend to explore crates

## Installation Options

Meuse can be deployed using Docker (recommended) or manually. There are three Git index repository options:

1. **Local Git repository** - Limited to local machine usage
2. **GitHub fork method** - ⚠️ Crate metadata becomes public
3. **Self-hosted private Git repository** - ✅ Recommended for complete privacy

## Docker Installation

### Prerequisites

- Docker and Docker Compose installed
- Domain name (or use `localhost` for testing)
- Git installed

### 1. Docker Image

The Meuse Docker image is available on Docker Hub:

```bash
# Pull the latest image
docker pull mokhtarabadi/meuse:latest

# Or pull a specific version
docker pull mokhtarabadi/meuse:1.4.0
```

### 2. Prepare Project Directory

```bash
# Create project directory
mkdir meuse-registry && cd meuse-registry

# Download required files
curl -O https://raw.githubusercontent.com/mokhtarabadi/meuse/master/docker-compose.yml
curl -O https://raw.githubusercontent.com/mokhtarabadi/meuse/master/nginx.conf
curl -O https://raw.githubusercontent.com/mokhtarabadi/meuse/master/.env.example
mkdir config && curl -o config/config.yaml https://raw.githubusercontent.com/mokhtarabadi/meuse/master/config/config.yaml
```

### 3. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Generate secure passwords (Linux/Mac)
sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -base64 32)/" .env
sed -i "s/MEUSE_FRONTEND_SECRET=.*/MEUSE_FRONTEND_SECRET=$(openssl rand -hex 32)/" .env
sed -i "s/DOMAIN=.*/DOMAIN=localhost/" .env
sed -i "s/PORT=.*/PORT=8080/" .env

# Edit with your domain
nano .env  # Change DOMAIN=localhost to your actual domain
```

### 4. Set Up Git Index Repository

Choose one of the following options:

#### Option 1: Local Git Repository

```bash
# Initialize local Git repository
mkdir -p ./index
cd ./index
git init

# Set up Git user for the repository
git config user.name "Meuse Registry"
git config user.email "registry@example.com"

# Create the crate index structure
mkdir -p 1 2 3

# Create config.json
cat > config.json << EOF
{
    "dl": "http://localhost:8080/api/v1/crates",
    "api": "http://localhost:8080",
    "allowed-registries": []
}
EOF

# Commit the initial structure
git add .
git commit -m "Initialize local crate registry index"
cd ../
```

#### Option 2: GitHub Fork (⚠️ Public Metadata)

```bash
# 1. First, fork https://github.com/rust-lang/crates.io-index on GitHub

# 2. Clone your fork (replace YOUR_USERNAME)
git clone https://github.com/YOUR_USERNAME/crates.io-index.git temp-index
cd temp-index

# 3. Configure the index for your domain
cat > config.json << EOF
{
    "dl": "http://localhost:8080/api/v1/crates",
    "api": "http://localhost:8080",
    "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
}
EOF

# 4. Commit and push
git add config.json
git commit -m "Configure for Meuse registry"
git push origin master

# 5. Move to final location
cd ..
mv temp-index index

# 6. Update config/config.yaml
sed -i 's/YOUR_USERNAME/your-actual-github-username/' config/config.yaml
```

#### Option 3: Self-hosted Private Git Repository (✅ Recommended)

```bash
# 1. Initialize private Git repository
mkdir -p ./index
cd ./index
git init

# 2. Set up Git user for the repository
git config user.name "Meuse Registry"
git config user.email "registry@example.com"

# 3. Create the crate index structure
mkdir -p 1 2 3

# 4. Create index config
cat > config.json << EOF
{
    "dl": "https://your-domain.com/api/v1/crates",
    "api": "https://your-domain.com",
    "allowed-registries": []
}
EOF

# 5. Commit the initial structure
git add .
git commit -m "Initialize private crate registry index"
cd ../

# 6. Create bare repository for HTTP access
mkdir -p git-repos
git clone --bare index git-repos/index.git

# 7. Configure bare repository
cd git-repos/index.git
git config http.receivepack true
git config http.uploadpack true
cd ../..
```

### 5. Update Configuration

Make sure your config.yaml file has the correct database password that matches your .env file:

```bash
# Get the PostgreSQL password from .env
POSTGRES_PWD=$(grep POSTGRES_PASSWORD .env | cut -d= -f2)

# Update config.yaml with the correct password syntax
cat > config/config.yaml << EOF
database:
  user: "meuse"
  password: "${POSTGRES_PWD}"
  host: "postgres"
  port: 5432
  name: "meuse"

http:
  address: "0.0.0.0"
  port: 8855

logging:
  level: "info"
  console:
    encoder: "json"

metadata:
  type: "shell"
  path: "/app/index"
  target: "master"
  url: "http://localhost:8080/git/index.git" # For self-hosted Git
  # Or use "file:///app/index" for local Git
  # Or use "https://github.com/YOUR_USERNAME/crates.io-index" for GitHub fork

crate:
  store: "filesystem"
  path: "/app/crates"

frontend:
  enabled: true
  public: true
EOF
```

### 6. Deploy Services

```bash
# Start everything
docker compose up -d

# Wait for services to be ready (30-60 seconds)
sleep 45

# Check status
docker compose ps
```

### 7. Create Admin User

Once the services are running successfully:

```bash
# Generate password hash
PASSWORD_HASH=$(docker compose exec meuse java -jar /app/meuse.jar password your_admin_password | grep '$2a$' | tail -1)

# Create admin user
docker compose exec postgres psql -U meuse -d meuse -c "INSERT INTO users(id, name, password, description, active, role_id) VALUES ('f3e6888e-97f9-11e9-ae4e-ef296f05cd17', 'admin', '$PASSWORD_HASH', 'Administrator user', true, '867428a0-69ba-11e9-a674-9f6c32022150');"

# Create API token
TOKEN=$(curl -s --header "Content-Type: application/json" --request POST --data '{"name":"admin_token","validity":365,"user":"admin","password":"your_admin_password"}' http://localhost:8080/api/v1/meuse/token | jq -r '.token')

echo "Your API token: $TOKEN"
```

## Manual Installation

### Prerequisites

- JDK 17+
- Leiningen
- PostgreSQL 11+
- Git

### 1. Database Setup

```bash
# Create database and user
psql -U postgres -c "CREATE USER meuse WITH PASSWORD 'secure_password';"
psql -U postgres -c "CREATE DATABASE meuse OWNER meuse;"

# Enable required PostgreSQL extensions
psql -U postgres -d meuse -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
```

### 2. Clone and Build Meuse

```bash
# Clone repository
git clone https://github.com/mokhtarabadi/meuse.git
cd meuse

# Build Meuse
lein uberjar
```

### 3. Configure Meuse

Create a `config.yaml` file with the following content:

```yaml
database:
  user: "meuse"
  password: "secure_password"
  host: "localhost"
  port: 5432
  name: "meuse"

http:
  address: "0.0.0.0"
  port: 8855

logging:
  level: "info"
  console:
    encoder: "json"

metadata:
  type: "shell"
  path: "/path/to/git/index"
  target: "master"
  url: "file:///path/to/git/index"  # For local Git
  # Or use your GitHub fork URL: "https://github.com/YOUR_USERNAME/crates.io-index"

crate:
  store: "filesystem"
  path: "/path/to/crates"

frontend:
  enabled: true
  public: true
```

### 4. Setup Git Index Repository

Follow the same Git index setup steps as in the Docker installation, choosing one of the three options.

### 5. Run Meuse

```bash
# Run with the config file
java -jar target/meuse.jar -c config.yaml
```

### 6. Set Up Nginx as Reverse Proxy (Optional)

Create an nginx configuration file:

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://127.0.0.1:8855;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Configure Cargo

### Add Registry to Cargo Config

Add to `~/.cargo/config.toml`:

```toml
[registries.myregistry]
index = "http://localhost:8080"  # For local Git
# Or for GitHub fork: "https://github.com/YOUR_USERNAME/crates.io-index"
# Or for self-hosted Git: "http://your-domain.com/git/index.git"

# Optional: Make your registry the default
[source.crates-io]
replace-with = "myregistry"

[source.myregistry]
registry = "http://localhost:8080"  # Same as above
```

### Add Authentication Token

Add to `~/.cargo/credentials.toml`:

```toml
[registries.myregistry]
token = "YOUR_API_TOKEN"
```

## Using the Registry

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

## Troubleshooting

### Common Issues

1. **Connection refused errors**
    - Check if services are running: `docker compose ps`
    - Check logs: `docker compose logs meuse`
    - Verify health endpoints: `curl http://localhost/healthz`

2. **Database connection issues**
    - Ensure PostgreSQL is healthy: `docker compose logs postgres`
    - Verify the password in config.yaml matches the one in .env: `grep POSTGRES_PASSWORD .env`
    - Common error: "FATAL: password authentication failed for user 'meuse'" indicates a password mismatch
    - Make sure environment variables are being passed correctly
    - Try using a simple password temporarily for testing, then secure it later

3. **Git index issues**
    - Ensure the index repository is properly cloned: `docker compose exec meuse ls -la /app/index`
    - Check git credentials and permissions
    - Verify the repository URL in config matches your setup (local, GitHub or self-hosted)

4. **Permission denied errors**
    - Check Docker volume permissions
    - Ensure the meuse user can write to mounted directories

5. **Configuration syntax issues**
    - The config.yaml file is sensitive to YAML syntax and secrets formatting
    - For passwords, use: `password: "actual_password"` (with quotes)
    - For environment variables in config.yaml, use: `password: !secret "${ENV_VAR_NAME}"`

## Security Considerations

1. Change default passwords in `.env`
2. Use strong tokens for API access
3. Enable rate limiting in nginx
4. Perform regular backups of database and crate files
5. Monitor access logs for suspicious activity
6. Keep Docker images updated
7. Use HTTPS only in production
8. Restrict database access to localhost only

## Maintenance

### Backup and Recovery

```bash
# Database backup
docker compose exec postgres pg_dump -U meuse meuse > backup.sql

# Crate files backup
tar -czf crates-backup.tar.gz -C data crates/

# Git index backup
tar -czf index-backup.tar.gz -C data index/
```

```bash
# Restore database
docker compose exec -T postgres psql -U meuse meuse < backup.sql

# Restore crate files
tar -xzf crates-backup.tar.gz -C data/

# Restore git index
tar -xzf index-backup.tar.gz -C data/
```

### Git Repository Maintenance

```bash
# Clean up repository
cd index
git gc --prune=now
git repack -ad

# Verify repository integrity
git fsck --full

# Update bare repository from working repository (for self-hosted Git)
git push ../git-repos/index.git master
```
