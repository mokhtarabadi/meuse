# Meuse

A free crate registry for the Rust programming language.

It implements the [alternative registries](https://github.com/rust-lang/rfcs/blob/master/text/2141-alternative-registries.md) RFC and offers also various features (cf the `Features` section).

You can use Meuse to store your private crates, configure it to mirror crates.io...

Documentation is available at https://meuse.mcorbin.fr/ and in the [docs](./docs/) directory.

## Quick Start

The fastest way to get Meuse running with Docker:

```bash
# Clone the repository
git clone https://github.com/mcorbin/meuse.git
cd meuse

# Copy and configure environment variables
cp .env.example .env
# Edit .env to customize your settings

# Generate Git HTTP authentication
./scripts/gen-htpasswd.sh

# Start all services
docker compose up -d
```

The Meuse container will automatically initialize the Git repository on first run. No manual initialization is required!

For detailed instructions, see:

- [Quick Start Guide](./docs/installation/quick-start/_index.md) - Manual setup without Docker
- [Docker Deployment Guide](./docs/installation/docker-deployment/_index.md) - Full Docker setup
- [Git HTTP Backend Guide](./docs/installation/git-http-backend/_index.md) - Git server details

## Features

- [x] Complete implementation of the alternative registries RFC (including search).
- [x] crates.io mirroring.
- [x] Multiple backends for crates files: filesystem, S3.
- [x] Multiple ways of managing the Git crate Index: git command, JGit.
- [x] Integrated Git HTTP server for private registries.
- [x] Manage categories.
- [x] Manage users, roles, and tokens.
- [x] Manage crates.
- [x] Security: HTTPS support, TLS support for the PostgreSQL client.
- [x] Monitoring: Meuse exposes a Prometheus endpoint with various metrics (HTTP server, database pool, JVM metrics...).
- [x] Small frontend to explore crates.
- [x] Automatic user creation from configuration.
- [x] Automatic Git repository initialization on first run.

## Plan

Take a look at https://meuse.mcorbin.fr/roadmap/.

## Changelog

- 2025-09-12: Switched to non-bare git repository for crate index and metadata. Meuse now requires a non-bare repo
  because JGit and rollback operations fail with bare repos. Docker and entrypoint.sh are updated, and the build-jgit
  code now checks for misconfigurations.

## Troubleshooting

If you encounter an error like:

```
org.eclipse.jgit.errors.NoWorkTreeException: Bare Repository has neither a working tree, nor an index
```

You must ensure your crate index repo is NOT bare. Re-initialize using:

```bash
git init
```

Do NOT use `git init --bare`.

See [docs/installation/docker-deployment](./docs/installation/docker-deployment/_index.md)
and [docs/installation/git-http-backend](./docs/installation/git-http-backend/_index.md) for updated deployment
instructions.
