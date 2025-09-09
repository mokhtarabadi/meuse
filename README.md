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
   DOMAIN=your-domain.com
   ```

3. **Setup directories and permissions:**
   ```bash
   mkdir -p config crates index git-repos
   chown -R 999:999 index crates git-repos
   ```

4. **Choose index protocol:**

   **Option A: Git Protocol (Recommended)**
   ```bash
   cd index
   git init
   git config user.name "Meuse Registry"
   git config user.email "registry@example.com"
   mkdir -p 1 2 3
   echo '{"dl":"http://localhost:8080/api/v1/crates","api":"http://localhost:8080","allowed-registries":[]}' > config.json
   git add . && git commit -m "Init registry"
   cd ..
   git clone --bare index git-repos/index.git
   ```

   **Option B: Sparse Protocol (Faster)**
   ```bash
   mkdir -p index/1 index/2 index/3
   echo '{"dl":"http://localhost:8080/api/v1/crates","api":"http://localhost:8080","allowed-registries":[]}' > index/config.json
   ```

5. **Create config file:**
   ```bash
   cat > config/config.yaml << EOF
   database:
     user: "meuse"
     password: "\${POSTGRES_PASSWORD}"
     host: "postgres"
     port: 5432
     name: "meuse"

   http:
     address: "0.0.0.0"
     port: 8855

   logging:
     level: "info"

   metadata:
     type: "shell"
     path: "/app/index"
     target: "master"
     url: "file:///app/index"  # or your Git URL

   crate:
     store: "filesystem"
     path: "/app/crates"

   frontend:
     enabled: true
     public: true
   EOF
   ```

6. **Deploy:**
   ```bash
   docker compose up -d
   ```

7. **Create admin user:**
   ```bash
   # Generate password hash
   HASH=$(docker compose exec meuse java -jar /app/meuse.jar password your_password)

   # Create user in database
   docker compose exec postgres psql -U meuse -d meuse -c "
   INSERT INTO users(id, name, password, description, active, role_id)
   VALUES ('admin-id', 'admin', '$HASH', 'Admin', true, 'role-id');"

   # Get API token
   curl -X POST http://localhost:8080/api/v1/meuse/token \
     -H "Content-Type: application/json" \
     -d '{"name":"admin","password":"your_password"}'
   ```

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
- `DOMAIN`: Your registry domain

### Config File (config.yaml)
- **Database**: Connection settings
- **HTTP**: Server address and port
- **Metadata**: Index type (shell/git), path, URL
- **Crate**: Storage backend and path
- **Frontend**: Enable/disable web UI

## Usage

### Configure Cargo

Add to `~/.cargo/config.toml`:
```toml
[registries.myregistry]
index = "http://localhost:8080/git/index.git"  # Git protocol
# OR
index = "sparse+http://localhost:8080/index/"  # Sparse protocol
```

Add to `~/.cargo/credentials.toml`:
```toml
[registries.myregistry]
token = "your_api_token"
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
