# Meuse - Private Rust Crate Registry

A free, open-source private crate registry for Rust that implements the [alternative registries RFC](https://github.com/rust-lang/rfcs/blob/master/text/2141-alternative-registries.md). Host private crates, mirror crates.io, and manage everything via a web interface and REST API.

## Features

- Full alternative registries RFC support (including search)
- Crates.io mirroring
- Multiple storage backends (filesystem, S3)
- Git and sparse index protocols
- User management with roles and tokens
- Web frontend for crate exploration
- REST API for automation
- Production-ready Docker deployment
- Prometheus metrics endpoint

## Prerequisites

- Docker and Docker Compose
- Git
- Domain name (optional, use `localhost` for testing)

## Quick Start (Docker)

1. **Clone and setup:**
   ```bash
   git clone https://github.com/mokhtarabadi/meuse.git
   cd meuse
   cp .env.example .env
   ```

2. **Configure environment:**
   Edit `.env` with your settings:
   ```bash
   POSTGRES_PASSWORD=your_secure_password
   MEUSE_FRONTEND_SECRET=your32charalphanumericsecret
   DOMAIN=your-domain.com  # Your custom domain (e.g. registry.mycompany.com)
   MEUSE_PROTOCOL=http     # Set to https if behind SSL proxy

   # Optional: Initialization mode (default: local)
   MEUSE_INIT_MODE=local  # Options: local, github, sparse

   # For GitHub fork mode:
   # GITHUB_REPO_URL=https://github.com/YOUR_USERNAME/crates.io-index
   ```

## Production Deployment with Custom Domains and HTTPS

For production use, it's recommended to deploy Meuse behind a reverse proxy (e.g., Nginx, Caddy, Apache, or a cloud load
balancer) with HTTPS/TLS enabled.

**Steps:**

1. Set up your reverse proxy/service with SSL certificates for your custom domain (e.g., registry.mycompany.com).
2. Forward requests from `https://your-domain.com` to Meuse's container `http://localhost:8080`.
3. Set the environment variable in `.env`:
   ```
   DOMAIN=your-domain.com
   MEUSE_PROTOCOL=https
   ```
4. In your Cargo configuration (`config.toml`), always use the public protocol/domain:

   ```toml
   [registries.myregistry]
   index = "sparse+https://your-domain.com/index/"
   # or for Git protocol (if used):
   index = "https://your-domain.com/git/index.git"
   ```

5. For API calls, reference your domain and protocol:
   ```
   curl -X POST https://your-domain.com/api/v1/meuse/token \
     -H "Content-Type: application/json" \
     -d '{"name":"tech_token",...}'
   ```

**Notes:**

- Meuse itself does not terminate TLS; use a proxy for HTTPS.
- Set `MEUSE_PROTOCOL=https` so that generated URLs in `config.json` and other endpoints match your external scheme.
- If you change your domain or protocol, rebuild or override your index `config.json`.

3. **Setup directories:**
    ```bash
    mkdir -p config
    ```
   Note: The `index` and `crates` directories are created automatically by the init service with proper permissions (UID
   999).

4. **Initialize registry (automated):**
    ```bash
    # Run initialization service (runs once and exits)
    docker compose --profile init run --rm init

    # This will automatically:
    # - Create Git repository structure (for local/github modes)
    # - Set up bare repository for HTTP access
    # - Configure config.json with proper URLs
    ```

   > **Note**: The initialization service uses the official [alpine/git](https://hub.docker.com/r/alpine/git) image
   which provides git and other essential tools in a minimal container. This eliminates the need for a custom
   initialization image while maintaining all functionality.

5. **Create config file:**
    ```bash
    cat > config/config.yaml << EOF
    database:
      user: "meuse"
      password: !envvar POSTGRES_PASSWORD
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
      url: "file:///app/index"  # or your Git URL

    crate:
      store: "filesystem"
      path: "/app/crates"
      # Or for S3 storage:
      # store: "s3"
      # access-key: !envvar S3_ACCESS_KEY_ENV
      # secret-key: !envvar S3_SECRET_KEY_ENV
      # endpoint: "your-s3-endpoint"
      # bucket: "your-bucket-name"

    frontend:
      enabled: true
      public: true  # Set to false for production
      secret: !envvar MEUSE_FRONTEND_SECRET
    EOF
    ```

6. **Deploy:**
    ```bash
    docker compose up -d
    ```

   **Important**: Wait at least 45 seconds after starting services before proceeding to user creation. This allows the
   database to fully initialize and the Meuse application to become ready.

7. **Create users and tokens:**
   ```bash
   # First, create an admin user for initial setup

   # Generate password hash (using '!secret' in config as recommended)
   HASH=$(docker compose exec meuse java -jar /app/meuse.jar password secure_admin_password)

   # Create admin user in database
   docker compose exec postgres psql -U meuse -d meuse -c "
   INSERT INTO users(id, name, password, description, active, role_id)
   VALUES ('550e8400-e29b-41d4-a716-446655440000', 'admin', '$HASH', 'Admin user', true, '867428a0-69ba-11e9-a674-9f6c32022150');"

   # Now create a tech user for day-to-day operations
   TECH_HASH=$(docker compose exec meuse java -jar /app/meuse.jar password secure_tech_password)

   # Create tech user in database
   docker compose exec postgres psql -U meuse -d meuse -c "
   INSERT INTO users(id, name, password, description, active, role_id)
   VALUES ('550e8400-e29b-41d4-a716-446655440001', 'tech_user', '$TECH_HASH', 'Technical user for crate management', true, 'a5435b66-69ba-11e9-8385-8b7c3810e186');"

   # Get an API token for the tech user (valid for 365 days)
   # Replace ${PROTOCOL} and ${DOMAIN} with your actual values from .env
   curl -X POST ${PROTOCOL}://${DOMAIN}:8080/api/v1/meuse/token \
     -H "Content-Type: application/json" \
     -d '{"name":"tech_token","validity":365,"user":"tech_user","password":"secure_tech_password"}'
   # The response will contain your token: {"token":"your-token-value"}
   ```

   # Note: The UUIDs used above are the fixed IDs for the admin and tech roles in Meuse:
   # - Admin role ID: 867428a0-69ba-11e9-a674-9f6c32022150
   # - Tech role ID: a5435b66-69ba-11e9-8385-8b7c3810e186

## Manual Installation

1. **Install dependencies:**
   - JDK 17+
   - Leiningen
   - PostgreSQL 11+
   - Git

2. **Setup database:**
   ```bash
   psql -U postgres -c "CREATE USER meuse WITH PASSWORD 'secure_password';"
   psql -U postgres -c "CREATE DATABASE meuse OWNER meuse;"
   psql -U postgres -d meuse -c "CREATE EXTENSION pgcrypto;"
   ```

3. **Build and run:**
   ```bash
   git clone https://github.com/mokhtarabadi/meuse.git
   cd meuse
   lein uberjar
   java -jar target/uberjar/meuse-*-standalone.jar -c config.yaml
   ```

## Configuration

### Environment Variables (.env)
- `POSTGRES_PASSWORD`: Database password
- `MEUSE_FRONTEND_SECRET`: 32+ character session secret
- `DOMAIN`: Your registry domain (default: localhost)
- `MEUSE_PROTOCOL`: Protocol to use in registry URLs (http or https, default: http)
- `MEUSE_INIT_MODE`: Initialization mode (local/github/sparse, default: local)
- `GITHUB_REPO_URL`: GitHub repository URL for fork mode
- `S3_ACCESS_KEY_ENV`: (Optional) When using S3 storage, the access key
- `S3_SECRET_KEY_ENV`: (Optional) When using S3 storage, the secret key

### Config File (config.yaml)

> **Important**: Meuse uses the `!secret` tag for passwords and other sensitive information. This provides additional
> security measures for these values. Use this tag for all sensitive configuration values.

- **Database**: Connection settings
    - `user`: Database username
  - `password`: Database password (**use `!envvar POSTGRES_PASSWORD` format**)
    - `host`: Database hostname
    - `port`: Database port
    - `name`: Database name
    - `max-pool-size`: (Optional) Connection pool size (default: 2)
    - `schema`: (Optional) PostgreSQL schema to use
    - `ssl-mode`: (Optional) PostgreSQL verify mode (default: verify-full)
    - `cacert`, `cert`, `key`: (Optional) Client certificates for TLS connections

- **HTTP**: Server address and port
    - `address`: Address to bind to
    - `port`: Port to listen on
    - `cacert`, `cert`, `key`: (Optional) Server certificates for TLS

- **Logging**: Log configuration
    - `level`: Log level (debug, info, warn, error)
    - `console`: Console output configuration
        - `encoder`: Log format (json or plain)
    - `overrides`: (Optional) Per-package log levels

- **Metadata**: Index type and configuration
    - `type`: Index management type:
        - `shell`: Shell out to git command
            - `path`: Local path to Git index
            - `target`: Branch containing metadata files (e.g., `master` or `origin/master`)
            - `url`: URL of Git index
        - `jgit`: Use Java implementation of Git
            - `path`: Local path to Git index
            - `target`: Branch containing metadata files
            - `username`: Git username
          - `password`: Git password or token (**use `!envvar` for environment variables**)

- **Crate**: Storage backend and configuration
    - `store`: Backend type
        - `filesystem`:
            - `path`: Local path for crate files
        - `s3`:
            - `access-key`: S3 access key (**use `!envvar S3_ACCESS_KEY_ENV` for environment variables**)
            - `secret-key`: S3 secret key (**use `!envvar S3_SECRET_KEY_ENV` for environment variables**)
            - `endpoint`: S3 endpoint URL
            - `bucket`: S3 bucket name
            - `prefix`: (Optional) Prefix for S3 keys

- **Frontend**: Web UI configuration
    - `enabled`: Enable or disable the frontend (true/false)
    - `public`: Disable frontend authentication (true/false)
  - `secret`: Random string with at least 32 characters for session encryption (*
    *use `!envvar MEUSE_FRONTEND_SECRET` format**)

## Usage

### Configure Cargo

Add to `~/.cargo/config.toml` (replace `${DOMAIN}` and `${PROTOCOL}` with your settings from `.env`):
```toml
[registries.myregistry]
# Choose ONE of the following index options:

# Option 1: Git protocol (classic)
index = "${PROTOCOL}://${DOMAIN}/git/index.git"

# Option 2: Sparse protocol (Cargo 1.68+, recommended)
index = "sparse+${PROTOCOL}://${DOMAIN}/index/"
```

Add to `~/.cargo/credentials.toml`:
```toml
[registries.myregistry]
token = "your_api_token"  # The token value received from the API
```

### Publish Crates
```bash
cargo publish --registry myregistry
```

### Use Private Crates
In `Cargo.toml`:
```toml
[dependencies]
my-crate = { version = "1.0", registry = "myregistry" }
```

## Registry Protocols

Meuse supports two protocols for registry index access:

### Git Protocol

The Git protocol is the classic approach used by crates.io and early alternative registries.

**Pros:**

- Compatible with all Cargo versions
- Well-tested and stable

**Cons:**

- Requires Git to be installed on the client
- More complex setup (bare repository configuration)
- Higher overhead for network operations

### Sparse Protocol

The sparse protocol is a newer, more efficient approach that doesn't require Git.

**Pros:**

- More efficient - only downloads needed index files
- No Git dependency required
- Simpler server setup (just static files)
- Better performance for large registries

**Cons:**

- Requires Cargo 1.68+ on clients
- Newer with potentially fewer tools supporting it

**Recommendation:** Use the sparse protocol when all clients are running Cargo 1.68 or newer. Fall back to the Git
protocol for compatibility with older clients.

## Registry Index Format

Meuse implements
the [Alternative Registries RFC](https://github.com/rust-lang/rfcs/blob/master/text/2141-alternative-registries.md)
which defines the registry index format:

- The registry index is a Git repository
- It contains a `config.json` file with registry configuration:
  ```json
  {
    "dl": "${PROTOCOL}://${DOMAIN}:8080/api/v1/crates/{crate}/{version}/download",
    "api": "${PROTOCOL}://${DOMAIN}:8080",
    "allowed-registries": []
  }
  ```
  The `allowed-registries` field lists other registry URLs that dependencies can use. An empty array means no external
  dependencies are allowed.

- Crate metadata files are stored in directories based on their name length:
    - One-letter crates: `1/`
    - Two-letter crates: `2/`
    - Three-letter crates: `3/a/` (where 'a' is the first letter)
    - Four or more letters: `sa/mp/sample` (first two letters, then next two letters)

## Mirroring crates.io

Meuse can act as a mirror for crates.io:

1. Fork the [crates.io-index](https://github.com/rust-lang/crates.io-index)
2. Update the `config.json` in your fork to point to your Meuse instance
3. Configure Cargo to use your mirror

When a crate is requested through the mirror, Meuse will:

- Check if the crate is already cached locally
- If not, download it from crates.io, cache it, and serve it

## Metrics and Monitoring

Meuse exposes a Prometheus metrics endpoint at `/metrics` with information about:

- JVM metrics (memory, GC, threads)
- System metrics (file descriptors, uptime, processor)
- HTTP request metrics (duration, counts by status code)
- Database connection pool metrics
- Registry statistics (crate counts, download counts)

You can integrate with monitoring systems like Prometheus and Grafana to visualize metrics and set up alerts.

## User Roles and Permissions

Meuse has three built-in user roles:

- **Admin** (UUID: 867428a0-69ba-11e9-a674-9f6c32022150): Full access to all features
- **Tech** (UUID: a5435b66-69ba-11e9-8385-8b7c3810e186): Can publish crates and manage most resources
- **Read-Only**: View-only access to the registry

Users must be created by an admin, either through the API or by direct database insertion. Each user can be assigned
tokens with expiration dates for API access and Cargo authentication.

## Troubleshooting

### Common Issues

**Connection Refused**
- Check services: `docker compose ps`
- View logs: `docker compose logs meuse`
- Test health: `curl http://localhost:8080/healthz`

**Database Errors**
- Verify password in `.env` matches `config.yaml`
- Check PostgreSQL logs: `docker compose logs postgres`

**Permission Errors**
- Ensure directories owned by UID 999: `chown -R 999:999 index crates git-repos`
- Check Docker volume mounts

**Git Issues**
- For sparse protocol: Verify Cargo 1.68+: `cargo --version`
- For Git protocol: Check repository setup and permissions

**404 Errors**
- Confirm index structure exists
- Verify Nginx configuration for `/index/` or `/git/` paths
- Check that your `DOMAIN` and `MEUSE_PROTOCOL` settings are correct in `.env`
- Verify domain configuration in your reverse proxy

**Initialization Troubleshooting**

- When running the init service (`docker compose --profile init run --rm init`), look for these success indicators:
  ```
  ✓ Git operation successful: git init
  ✓ Created config.json
  ✓ Git operation successful: git commit
  ✓ Git operation successful: git clone --bare
  Setting proper permissions (UID/GID: 999:999)...
  ✓ Initialization completed successfully!
  ```
- If the init script fails, check for error messages that indicate which specific operation failed
- For permission errors during crate publishing, ensure the meuse service volume mount for index is writeable (not
  read-only)
- After initialization, wait 45 seconds before creating users to ensure all services are fully ready

**Domain/Protocol Issues**

- If you changed your domain or protocol after initialization, you may need to rebuild the index or manually update
  `config.json`
- For HTTPS deployments, ensure your SSL certificates are valid and trusted
- Check that client configs (`~/.cargo/config.toml`) use the same domain and protocol as your server

### Getting Help
- Check logs: `docker compose logs`
- Test endpoints: `curl http://localhost:8080/api/v1/meuse/stats`
- GitHub issues: [Report bugs](https://github.com/mokhtarabadi/meuse/issues)

## Security & Maintenance

- Use strong passwords and tokens
- Enable HTTPS in production
- Regular backups: `docker compose exec postgres pg_dump -U meuse meuse > backup.sql`
- Keep images updated: `docker compose pull`
- Monitor logs for suspicious activity

## Contributing

- Fork the repository
- Create a feature branch
- Submit a pull request
- See [docs/](docs/) for detailed documentation

---

**Version:** 1.4.0 | **License:** Eclipse Public License 2.0 | **Source:** [GitHub](https://github.com/mokhtarabadi/meuse)

