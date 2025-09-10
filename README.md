# Meuse - Private Rust Registry

[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)](https://docker.com)
[![Clojure](https://img.shields.io/badge/Clojure-%23Clojure.svg?style=for-the-badge&logo=Clojure&logoColor=Clojure)](https://clojure.org)
[![Rust](https://img.shields.io/badge/rust-%23000000.svg?style=for-the-badge&logo=rust&logoColor=white)](https://rust-lang.org)

Meuse is a **production-ready private Rust registry** that implements the [alternative registries RFC](https://github.com/rust-lang/rfcs/blob/master/text/2141-alternative-registries.md) and supports both **Git protocol** and **Sparse protocol** for maximum compatibility and performance.

## ✨ Features

- 🚀 **Sparse Protocol Support** - Fast, efficient crate discovery without Git clones
- 🔐 **Git Protocol Support** - Full compatibility with traditional Git-based registries
- 🐳 **Docker Ready** - Complete containerized setup with PostgreSQL and Git server
- 🔒 **Authentication & Authorization** - Token-based auth with role-based permissions
- 📊 **Web Frontend** - User-friendly interface for crate management
- 📈 **Statistics & Monitoring** - Built-in metrics and health checks
- 🔄 **Mirroring Support** - Can mirror crates.io for offline usage
- ☁️ **Multiple Storage Backends** - Filesystem and S3 support
- 🏗️ **Production Ready** - Comprehensive logging, health checks, and monitoring

## 🏃‍♂️ Quick Start

### Prerequisites

- Docker & Docker Compose
- Git (for local development)

### 1. Clone and Setup

```bash
git clone <repository-url>
cd meuse
cp .env.example .env
```

### 2. Configure Environment

Edit `.env` with your settings:

```bash
# Essential settings to customize:
POSTGRES_PASSWORD=your_secure_db_password
MEUSE_FRONTEND_SECRET=your_32_char_random_string
ADMIN_PASSWORD=your_admin_password
GIT_SERVER_PASSWORD=your_git_server_password
```

### 3. Launch Services

```bash
docker-compose up -d
```

### 4. Access Your Registry

- **Registry API**: http://localhost:8855
- **Web Frontend**: http://localhost:8855/front
- **Git Server**: http://localhost:8080

## 📋 Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Cargo Client  │────│   Meuse API     │────│  PostgreSQL DB  │
│                 │    │   (Port 8855)   │    │                 │
│ • Sparse Protocol│    │                 │    │ • Users         │
│ • Git Protocol   │    │ • Authentication │    │ • Crates        │
│ • Token Auth     │    │ • Authorization  │    │ • Tokens        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Git Server    │
                    │   (Port 8080)   │
                    │                 │
                    │ • Index Repo    │
                    │ • Smart HTTP    │
                    │ • Auto-init     │
                    └─────────────────┘
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `POSTGRES_PASSWORD` | Database password | Required |
| `MEUSE_FRONTEND_SECRET` | Frontend encryption key (32+ chars) | Required |
| `ADMIN_PASSWORD` | Admin user password | Required |
| `GIT_SERVER_PASSWORD` | Git server authentication | Required |
| `MEUSE_PORT` | HTTP port for Meuse | 8855 |
| `GIT_SERVER_PORT` | HTTP port for Git server | 8080 |

### User Roles

- **admin**: Full system access
- **tech**: CI/CD operations, crate publishing
- **read-only**: View-only access

## 🚀 Publishing Crates

### 1. Configure Cargo

Create `~/.cargo/config.toml`:

```toml
[registries.meuse]
protocol = "sparse"
index = "sparse+http://localhost:8855/api/v1/crates/"
```

### 2. Create Authentication Token

```bash
curl -X POST http://localhost:8855/api/v1/meuse/token/ \
  -H "Content-Type: application/json" \
  -d '{"name": "publish-token", "user": "admin", "password": "your_admin_password", "validity": 365}'
```

### 3. Configure Token

Add to `~/.cargo/credentials.toml`:

```toml
[registries.meuse]
token = "your-token-here"
```

### 4. Publish

```bash
cd your-rust-project
cargo publish --registry meuse
```

## 📦 Consuming Crates

### Add to Cargo.toml

```toml
[dependencies]
your-crate = { version = "0.1.0", registry = "meuse" }
```

### Or set as default registry

```toml
[registries.meuse]
protocol = "sparse"
index = "sparse+http://localhost:8855/api/v1/crates/"

[source.crates-io]
replace-with = "meuse"
```

## 🐳 Docker Services

### Included Services

1. **PostgreSQL** - Database for users, crates, and metadata
2. **Meuse** - Main registry application
3. **Git Server** - HTTP Git server for crate index

### Volumes

- `postgres_data` - Database persistence
- `git_data` - Git repository persistence
- `./data/crates` - Crate binary files
- `./data/logs` - Application logs

## 🔍 API Endpoints

### Crates
- `GET /api/v1/crates/config.json` - Registry configuration
- `PUT /api/v1/crates/new` - Publish new crate
- `GET /api/v1/crates/{name}/{version}/download` - Download crate

### Sparse Protocol
- `GET /api/v1/crates/3/{prefix}` - Index by 3-letter prefix
- `GET /api/v1/crates/2/{prefix}` - Index by 2-letter prefix
- `GET /api/v1/crates/1/{prefix}` - Index by 1-letter prefix

### Management
- `POST /api/v1/meuse/token/` - Create authentication token
- `GET /api/v1/meuse/crates` - List crates
- `POST /api/v1/meuse/user/` - Create user

## 🔐 Security Features

- **Token-based authentication** with configurable expiration
- **Role-based authorization** (admin, tech, read-only)
- **Password hashing** with bcrypt
- **HTTPS support** via reverse proxy
- **Environment-based secrets** management

## 📊 Monitoring

### Health Checks
- `GET /healthz` - Basic health check
- `GET /metrics` - Prometheus metrics

### Logs
- Structured JSON logging
- Configurable log levels
- Separate log volume for persistence

## 🛠️ Development

### Local Setup

```bash
# Install dependencies
lein deps

# Run tests
lein test

# Start development server
lein run
```

### Building

```bash
# Build JAR
lein uberjar

# Build Docker image
docker build -t meuse .
```

## 🔧 Advanced Configuration

### S3 Storage

```yaml
crate:
  store: s3
  access-key: !envvar S3_ACCESS_KEY
  secret-key: !envvar S3_SECRET_KEY
  endpoint: !envvar S3_ENDPOINT
  bucket: !envvar S3_BUCKET
```

### SSL/TLS with Reverse Proxy

```nginx
server {
    listen 443 ssl;
    server_name registry.your-domain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:8855;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    client_max_body_size 100M;
}
```

## 🐛 Troubleshooting

### Common Issues

**"failed to authenticate"**
- Verify token is valid and not expired
- Check user credentials and permissions

**"sparse registry requires HTTP URL"**
- Ensure URL starts with `http://` or `https://`
- Check network connectivity to registry

**"no matching package found"**
- Verify crate is published to registry
- Check registry configuration in Cargo

**Git server connection issues**
- Verify `GIT_SERVER_USER` and `GIT_SERVER_PASSWORD`
- Check Git server logs: `docker-compose logs git-server`

### Debug Commands

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs -f meuse
docker-compose logs -f git-server

# Test Git server
curl http://localhost:8080/index.git/info/refs

# Test sparse endpoint
curl http://localhost:8855/api/v1/crates/config.json
```

## 📚 Documentation

- [API Documentation](./docs/api/)
- [Configuration Guide](./docs/installation/configuration/)
- [Installation Guide](./docs/installation/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

Licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Clojure](https://clojure.org/)
- Uses [JGit](https://www.eclipse.org/jgit/) for Git operations
- Inspired by [crates.io](https://crates.io/)

---

**Ready to host your private Rust crates? Get started with Meuse today! 🚀**