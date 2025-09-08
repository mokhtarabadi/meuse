# Meuse

A free crate registry for the Rust programming language.

It implements the [alternative registries](https://github.com/rust-lang/rfcs/blob/master/text/2141-alternative-registries.md) RFC and offers also various features (cf the `Features` section).

You can use Meuse to store your private crates, configure it to mirror crates.io...

Documentation is available at https://meuse.mokhtarabadi.fr/

## 🐳 Docker Image

The Meuse Docker image is available on Docker Hub:

- **Latest:** `mokhtarabadi/meuse:latest`
- **Versioned:** `mokhtarabadi/meuse:1.3.0`

```bash
# Pull the latest image
docker pull mokhtarabadi/meuse:latest

# Or pull a specific version
docker pull mokhtarabadi/meuse:1.3.0
```

## 🚀 Quick Docker Setup

Deploy your private Rust registry with SSL in 5 minutes!

### One-Command Setup

```bash
curl -sSL https://raw.githubusercontent.com/mokhtarabadi/meuse/master/install.sh | bash
```

### Manual Setup

```bash
git clone https://github.com/mokhtarabadi/meuse.git
cd meuse
cp .env.example .env
# Edit .env with your domain and settings
docker compose up -d
```

📚 **Complete Setup Guide:** [QUICK_START.md](QUICK_START.md)

## Features

- [x] Complete implementation of the alternative registries RFC (including search).
- [x] crates.io mirroring.
- [x] Multiple backends for crates files: filesystem, S3.
- [x] Multiple ways of managing the Git crate Index: git command, JGit.
- [x] Manage categories.
- [x] Manage users, roles, and tokens.
- [x] Manage crates.
- [x] Security: HTTPS support, TLS support for the PostgreSQL client.
- [x] Monitoring: Meuse exposes a Prometheus endpoint with various metrics (HTTP server, database pool, JVM metrics...).
- [x] Small frontend to explore crates.

## Documentation

- 📖 **Quick Start:** [QUICK_START.md](QUICK_START.md) - 5-minute Docker setup with SSL
- 📋 **Full Guide:** [DOCKER_SETUP.md](DOCKER_SETUP.md) - Complete deployment documentation
- 🌐 **Official Docs:** https://meuse.mokhtarabadi.fr/

## Plan

Take a look at https://meuse.mokhtarabadi.fr/roadmap/.
