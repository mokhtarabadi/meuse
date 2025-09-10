# Meuse - Private Rust Registry

Meuse is a registry implementation for the [Rust](https://www.rust-lang.org) programming language. It implements
the [alternative registries](https://github.com/rust-lang/rfcs/blob/master/text/2141-alternative-registries.md) RFC
and [API](https://doc.rust-lang.org/cargo/reference/registries.html), and also exposes an API to manage users, crates,
tokens and categories. Meuse can store the crates binary files in various backends (filesystem, S3...).

It can also be used as a mirror for `crates.io`.

## Quick Start with Docker Compose

### Prerequisites

- Docker and Docker Compose installed
- Git installed locally

### Setup Steps

#### 1. Set Up Environment Variables

Copy the example environment file and customize it with your settings:

```bash
cp .env.example .env
```

Edit the `.env` file to set your own passwords and configuration values:

```bash
# Update passwords (at minimum)
vi .env   # or use your preferred editor
```

Important variables to customize:

- `POSTGRES_PASSWORD`: Database password
- `MEUSE_FRONTEND_SECRET`: Secret for the frontend (min 32 chars)
- `ADMIN_PASSWORD`, `TECH_PASSWORD`, `READONLY_PASSWORD`: User passwords

#### 2. Prepare the Git Index Repository

Meuse uses a Git repository to store metadata about crates. For this setup, we'll create a local Git repository:

```bash
# Create the index directory structure
mkdir -p ./data/index
cd ./data/index

# Initialize Git repository
git init

# Configure Git user for the repository
git config user.email "registry@meuse.local"
git config user.name "Meuse Registry"

# Set the branch name to 'master' (REQUIRED by Meuse)
# Meuse specifically looks for the 'master' branch, other branch names will cause errors
git branch -M master

# Create the config.json file for Cargo
cat > config.json << EOF
{
    "dl": "http://localhost:8855/api/v1/crates",
    "api": "http://localhost:8855"
}
EOF

# Add and commit the config file
git add config.json
git commit -m "Initial commit with registry configuration"

# Return to the main directory
cd ../..
```

> **Important**: Meuse requires the Git repository to use the `master` branch. Using any other branch name will cause
> errors when publishing crates.

#### 3. Start the Services

```bash
# Start the services in detached mode
docker-compose up -d

# Check logs
docker-compose logs -f meuse
```

The registry will be available at http://localhost:8855 with the frontend at http://localhost:8855/front

#### 4. Create and Manage Authentication Tokens

Meuse uses tokens for authentication. Here's how to create and manage them for the initial users defined in the
configuration:

##### Create a Token for Admin User

```bash
curl --header "Content-Type: application/json" --request POST \
  --data '{"name":"admin-token","validity":365,"user":"admin","password":"admin_password_change_me"}' \
  http://localhost:8855/api/v1/meuse/token
```

Response will contain the token:

```json
{"token":"your-token-will-appear-here"}
```

##### Create a Token for Technical User

```bash
curl --header "Content-Type: application/json" --request POST \
  --data '{"name":"tech-token","validity":365,"user":"tech","password":"tech_password_change_me"}' \
  http://localhost:8855/api/v1/meuse/token
```

##### List Tokens for a User

```bash
# First, save your token to a variable for easier use
TOKEN="your-token-from-above"

# List your own tokens
curl --header "Content-Type: application/json" \
  -H "Authorization: $TOKEN" \
  http://localhost:8855/api/v1/meuse/token

# For admin users - list tokens for another user
curl --header "Content-Type: application/json" \
  -H "Authorization: $TOKEN" \
  "http://localhost:8855/api/v1/meuse/token?user=tech"
```

##### Delete a Token

```bash
curl --header "Content-Type: application/json" --request DELETE \
  -H "Authorization: $TOKEN" \
  --data '{"name":"tech-token","user":"tech"}' \
  http://localhost:8855/api/v1/meuse/token
```

#### 5. Configure Cargo to Use Your Registry

Cargo supports multiple registry protocols. Here are different ways to configure your registry:

##### Option 1: Using Git Protocol (Recommended for Meuse)

Add the registry to your `~/.cargo/config.toml` with a file path to your local Git index:

```toml
[registries.meuse]
index = "file:///path/to/meuse/data/index"
```

For remote Git repositories:

```toml
[registries.meuse]
index = "https://github.com/yourusername/crates-index.git"
```

##### Option 2: Using Sparse Protocol

The sparse protocol is faster and more efficient as it doesn't require a full Git clone. To use it, configure your
`~/.cargo/config.toml` as follows:

```toml
[registries.meuse]
protocol = "sparse"
index = "sparse+http://localhost:8855/api/v1/crates/"
```

With HTTPS (if you have a proxy in front of Meuse):

```toml
[registries.meuse]
protocol = "sparse"
index = "sparse+https://your-domain.com/api/v1/crates/"
```

Add your token to `~/.cargo/credentials.toml`:

```toml
[registries.meuse]
token = "your-token-from-above"
```

#### 6. Publish a Crate

```bash
# Navigate to your crate directory
cd your-crate-directory

# Publish to your Meuse registry
cargo publish --registry meuse
```

#### 7. Using Your Registry for Dependencies

To use crates from your registry in your projects, add the `registry` key to your dependencies in `Cargo.toml`:

```toml
[dependencies]
crate-name = { version = "0.1.0", registry = "meuse" }
```

Or set your registry as the default for all dependencies by adding to `~/.cargo/config.toml`:

```toml
[source.crates-io]
replace-with = "meuse"

[source.meuse]
registry = "https://registry.your-domain.com/api/v1/index"
# Or for sparse protocol:
# protocol = "sparse"
# registry = "sparse+https://registry.your-domain.com/api/v1/crates/"
```

### User Roles and Permissions

Meuse has three user roles with different permissions:

- **admin**: Full access to all features
- **tech**: Most capabilities except some administrative functions
- **read-only**: Can only read data, cannot make changes

### API Capabilities

Meuse provides APIs for:

- **Crates**: Publish, yank, and download crates
- **Users**: Create, update, and delete users
- **Tokens**: Create and manage authentication tokens
- **Categories**: Categorize crates for easier discovery
- **Statistics**: View registry usage statistics

### Volumes

The following data directories and volumes are used:

- PostgreSQL data: Uses a named volume `postgres_data`
- Crates data: `./data/crates` - Stores the actual crate files
- Index data: `./data/index` - Git repository with crate metadata
- Logs: `./data/logs` - Application logs

## Advanced Configuration

### Environment Variables

The following environment variables can be configured in the `.env` file:

**Database:**

- `POSTGRES_USER`: PostgreSQL username
- `POSTGRES_PASSWORD`: PostgreSQL password
- `POSTGRES_DB`: PostgreSQL database name
- `POSTGRES_HOST`: PostgreSQL host (usually 'postgres' in Docker Compose)

**Meuse Server:**

- `MEUSE_PORT`: HTTP port for Meuse server (default: 8855)
- `MEUSE_FRONTEND_SECRET`: Secret for the frontend (at least 32 characters)

**Users:**

- `ADMIN_USER`, `ADMIN_PASSWORD`, `ADMIN_DESCRIPTION`: Admin user settings
- `TECH_USER`, `TECH_PASSWORD`, `TECH_DESCRIPTION`: Technical user settings
- `READONLY_USER`, `READONLY_PASSWORD`, `READONLY_DESCRIPTION`: Read-only user settings

**Git Configuration:**

- `GIT_EMAIL`: Email for Git commits
- `GIT_USERNAME`: Username for Git commits
- `GIT_PULL_REBASE`: Git pull rebase strategy (default: false)
- `GIT_MERGE_STYLE`: Git merge conflict style (default: diff3)
- `GIT_MERGE_FF`: Git fast-forward merge policy (default: only)

**S3 Storage (Optional):**

- `S3_ACCESS_KEY`: S3 access key
- `S3_SECRET_KEY`: S3 secret key
- `S3_ENDPOINT`: S3 endpoint URL
- `S3_BUCKET`: S3 bucket name

### Using S3 for Crate Storage

Edit `config/config.yaml` to use S3 instead of the filesystem:

```yaml
crate:
  store: s3
  access-key: "your-access-key"
  secret-key: "your-secret-key"
  endpoint: "s3-endpoint"
  bucket: "your-bucket-name"
```

### Setting Up as a Mirror for crates.io

Meuse can act as a mirror for crates.io, allowing you to cache crates locally.

To use this feature, create a fork of the [crates.io-index](https://github.com/rust-lang/crates.io-index) and configure
your Cargo to use your mirror.

### Setting Up with SSL/TLS via HTTP Proxy

For production environments, it's recommended to run Meuse behind a reverse proxy like Nginx or Traefik that handles
SSL/TLS termination.

#### Example Nginx Configuration

```nginx
server {
    listen 443 ssl http2;
    server_name registry.your-domain.com;
    
    # SSL configuration
    ssl_certificate /path/to/your/fullchain.pem;
    ssl_certificate_key /path/to/your/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Proxy settings
    location / {
        proxy_pass http://localhost:8855;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Increase upload size for crates
    client_max_body_size 100M;
}
```

With this setup, update your Cargo configuration to use HTTPS:

```toml
[registries.meuse]
protocol = "sparse"  # Or use Git protocol
index = "sparse+https://registry.your-domain.com/api/v1/crates/"
```

Also update the Git repository's `config.json` to use HTTPS URLs:

```json
{
    "dl": "https://registry.your-domain.com/api/v1/crates",
    "api": "https://registry.your-domain.com"
}
```

## Troubleshooting

- **Authentication Issues**: Ensure your token is valid and not expired
- **Git Access Problems**: Check Git configuration and permissions in the container
    - Verify the Git repository uses the `master` branch
    - If you see errors about 'master' not being a Git repository, check that the index directory is properly mounted
    - If publishing fails with Git errors but says the crate exists, it may have actually succeeded
- **Database Connection Errors**: Verify PostgreSQL is running and credentials are correct
- **SSL/TLS Certificate Issues**: When using a proxy with SSL, ensure certificates are valid and trusted by your client
- **Sparse Protocol**: Meuse supports the sparse protocol which avoids the need for a Git repository clone
- **Proxy Configuration**: Check that your proxy is correctly forwarding all necessary headers to Meuse

### Common Error Messages

#### "failed to authenticate when downloading repository"

This typically means your token is invalid or expired. Create a new token and update your credentials file.

#### "failed to download from registry at ..." (SSL errors)

This may indicate SSL certificate issues. Ensure your certificate is valid and trusted. You can check with:

```bash
curl -v https://your-registry-domain.com
```

#### "sparse registry requires HTTP URL"

Ensure that your sparse protocol URL points to an HTTP/HTTPS endpoint, not a Git repository.

#### "no matching package named ... found"

Check that your Git index is properly synchronized and that the crate is published to your registry.

## Additional Information

For more details on configuring and using Meuse, see the [official documentation](https://meuse.mcorbin.fr/).