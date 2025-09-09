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

### 4. Set Proper Directory Permissions

```bash
# The Meuse application runs as user:group 999:999 inside the Docker container
# You must ensure the directories have proper ownership
chown -R 999:999 ./index ./crates ./git-repos
chmod -R 755 ./index ./crates ./git-repos

# If you're using SELinux, you may also need to add proper context
# For example, on RHEL/CentOS/Fedora:
# chcon -Rt svirt_sandbox_file_t ./index ./crates ./git-repos
```

### 5. Set Up Git Index Repository

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

#### Option 4: Sparse Protocol Index (🚀 Most Efficient)

```bash
# 1. Initialize index directory structure
mkdir -p ./index
cd ./index

# 2. Create the crate index structure
mkdir -p 1 2 3

# 3. Create index config
cat > config.json << EOF
{
    "dl": "https://your-domain.com/api/v1/crates",
    "api": "https://your-domain.com",
    "allowed-registries": []
}
EOF
cd ../
```

The sparse protocol doesn't use Git, so you don't need to initialize a Git repository or create a bare clone.
However, the directory structure must be maintained for compatibility with both protocols.

### 6. Configure Git HTTP Backend

The Git repository needs to be served via HTTP for Cargo to access it. The included Nginx configuration includes a setup
for serving Git repositories, but requires additional packages:

```bash
# If you're using the Docker setup, this is handled automatically in docker-compose.yml

# For manual setup with Nginx, install the necessary packages
sudo apt-get install -y git fcgiwrap spawn-fcgi nginx

# Start fcgiwrap service
sudo systemctl enable fcgiwrap
sudo systemctl start fcgiwrap

# Ensure proper permissions
sudo chmod 755 /usr/lib/git-core/git-http-backend
```

Make sure your Nginx configuration includes the Git HTTP backend configuration:

```nginx
location /git/ {
    # Disable request body limits
    client_max_body_size 0;
    
    # Set git project root to your git-repos directory
    alias /path/to/git-repos/;
    
    # Handle Git HTTP protocol
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /usr/lib/git-core/git-http-backend;
    fastcgi_param PATH_INFO $uri;
    fastcgi_param GIT_PROJECT_ROOT /path/to/git-repos;
    fastcgi_param GIT_HTTP_EXPORT_ALL "";
    fastcgi_pass unix:/var/run/fcgiwrap.sock;
}
```

### 7. Update Configuration

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
  url: "https://your-domain.com/git/index.git" # For self-hosted Git
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

### 8. Deploy Services

```bash
# Start everything
docker compose up -d

# Wait for services to be ready (30-60 seconds)
sleep 45

# Check status
docker compose ps
```

### 9. Create Admin User

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
  url: "https://your-domain.com/git/index.git" # For self-hosted Git
  # Or use "file:///path/to/git/index" for local Git
  # Or use "https://github.com/YOUR_USERNAME/crates.io-index" for GitHub fork

crate:
  store: "filesystem"
  path: "/path/to/crates"

frontend:
  enabled: true
  public: true
```

### 4. Set Proper Directory Permissions

The Meuse application needs appropriate permissions to access and modify the crate and index directories:

```bash
# Determine which user will run Meuse
# If running as a service, create a dedicated user
sudo useradd -r meuse

# Set ownership of directories
sudo chown -R meuse:meuse /path/to/git/index
sudo chown -R meuse:meuse /path/to/crates

# Set appropriate permissions
sudo chmod -R 755 /path/to/git/index
sudo chmod -R 755 /path/to/crates
```

### 5. Setup Git Index Repository

Follow the same Git index setup steps as in the Docker installation, choosing one of the three options.

### 6. Configure Git HTTP Backend

The Git repository needs to be served via HTTP for Cargo to access it. The included Nginx configuration includes a setup
for serving Git repositories, but requires additional packages:

```bash
# If you're using the Docker setup, this is handled automatically in docker-compose.yml

# For manual setup with Nginx, install the necessary packages
sudo apt-get install -y git fcgiwrap spawn-fcgi nginx

# Start fcgiwrap service
sudo systemctl enable fcgiwrap
sudo systemctl start fcgiwrap

# Ensure proper permissions
sudo chmod 755 /usr/lib/git-core/git-http-backend
```

Make sure your Nginx configuration includes the Git HTTP backend configuration:

```nginx
location /git/ {
    # Disable request body limits
    client_max_body_size 0;
    
    # Set git project root to your git-repos directory
    alias /path/to/git-repos/;
    
    # Handle Git HTTP protocol
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME /usr/lib/git-core/git-http-backend;
    fastcgi_param PATH_INFO $uri;
    fastcgi_param GIT_PROJECT_ROOT /path/to/git-repos;
    fastcgi_param GIT_HTTP_EXPORT_ALL "";
    fastcgi_pass unix:/var/run/fcgiwrap.sock;
}
```

### 7. Run Meuse

```bash
# Run with the config file
java -jar target/meuse.jar -c config.yaml
```

### 8. Set Up Nginx as Reverse Proxy (Optional)

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
# Option 1: Git-based protocol (traditional)
[registries.myregistry]
index = "http://localhost:8080/git/index.git"  # For self-hosted Git
# Or for GitHub fork: "https://github.com/YOUR_USERNAME/crates.io-index"

# Option 2: Sparse protocol (more efficient)
[registries.myregistry]
index = "sparse+http://localhost:8080/index/"

# Optional: Make your registry the default
[source.crates-io]
replace-with = "myregistry"

[source.myregistry]
registry = "http://localhost:8080/git/index.git"  # Same as above for Git protocol
# Or for sparse protocol: registry = "sparse+http://localhost:8080/index/"
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
   - **Important**: The Meuse application runs as user:group 999:999 inside the container
   - Set correct ownership on mounted volumes: `chown -R 999:999 ./index ./crates ./git-repos`
   - If permission errors persist, you can add `user: "0:0"` to the meuse service in docker-compose.yml to run as root (
     less secure)

5. **Git HTTP backend issues**
    - Check if fcgiwrap is running: `systemctl status fcgiwrap`
    - Ensure git-http-backend is accessible: `ls -la /usr/lib/git-core/git-http-backend`
    - Verify Nginx can access the Git repositories: `sudo -u www-data ls -la /path/to/git-repos`
    - Test Git HTTP access: `curl -i http://localhost:8080/git/index.git/info/refs?service=git-upload-pack`
    - Common error: 404 - This usually means Nginx can't find git-http-backend or fcgiwrap.sock
    - Common error: 500 - Check Nginx error logs for issues with the Git backend

6. **Sparse protocol issues**
    - Verify index directory structure: Ensure the index has the correct structure with 1, 2, 3 directories
    - Check Nginx configuration: Make sure `/index/` location is properly configured to serve files
    - Test config file access: `curl -i http://localhost:8080/index/config.json`
    - Verify Cargo version: Sparse protocol requires Cargo 1.68+ (`cargo --version` to check)
    - For 404 errors: Make sure your index directory is correctly mounted in the Nginx container

7. **Configuration syntax issues**
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

## Registry Protocols

Meuse supports two protocols for accessing the crate registry:

### 1. Git-based Protocol (Traditional)

This is the original protocol used by Cargo, where crate metadata is stored in a Git repository.

**Advantages:**

- Compatible with all Cargo versions
- Works with both public and private repositories

**Disadvantages:**

- Requires Git to be installed
- Downloads the entire index which can be slow
- More resource-intensive

### 2. Sparse Protocol (Modern)

A newer, more efficient protocol that only downloads the metadata needed for specific crates.

**Advantages:**

- Faster dependency resolution
- Lower bandwidth usage
- No Git dependency
- More efficient caching

**Disadvantages:**

- Only supported in newer Cargo versions (1.68+)
- May require additional configuration

To use the sparse protocol, prefix the index URL with `sparse+` in your Cargo configuration:

```toml
[registries.myregistry]
index = "sparse+https://your-domain.com/index/"
```

