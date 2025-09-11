# Meuse

A free crate registry for the Rust programming language.

It implements the [alternative registries](https://github.com/rust-lang/rfcs/blob/master/text/2141-alternative-registries.md) RFC and offers also various features (cf the `Features` section).

You can use Meuse to store your private crates, configure it to mirror crates.io...

Documentation is available at https://meuse.mcorbin.fr/ and in the [docs](./docs/) directory.

## Quick Start

For a quick local setup, see the [Quick Start Guide](./docs/installation/quick-start/_index.md) which covers setting up
the complete system with Docker Compose.

For setting up a lightweight Git HTTP server for your registry, see
the [Git HTTP Backend Guide](./docs/installation/git-http-backend/_index.md).

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

## Plan

Take a look at https://meuse.mcorbin.fr/roadmap/.
