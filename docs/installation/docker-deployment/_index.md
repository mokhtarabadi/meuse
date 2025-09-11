---
title: Docker Deployment
weight: 25
disableToc: false
---

# Docker Deployment

This guide explains how to deploy Meuse using Docker Compose, which provides a complete environment with PostgreSQL, Git
HTTP server, and the Meuse application.

## Prerequisites

- Docker and Docker Compose installed
- Git installed (for initial repository setup)
- Basic understanding of Docker concepts

## Quick Start

1. **Clone the repository**

   ```bash
   git clone https://github.com/mcorbin/meuse.git
   cd meuse
   ```

2. **Prepare environment variables**

   ```bash
   cp .env.example .env
   # Edit .env to customize settings
   ```

3. **Create required directories and setup Git repository**

   ```bash
   # Create directories
   mkdir -p git-data crates
   
   # Initialize Git repository
   cd git-data
   git init --bare myindex.git
   
   # Create config.json for Cargo
   echo '{
     "dl": "http://localhost:8855/api/v1/crates",
     "api": "http://localhost:8855",
     "allowed-registries": ["https://github.com/rust-lang/crates.io-index"]
   }' > config.json
   
   # Copy config into repository
   cp config.json myindex.git/
   cd ..
   ```

4. **Generate htpasswd file for Git HTTP authentication**

   ```bash
   ./scripts/gen-htpasswd.sh
   ```

5. **Start the services**

   ```bash
   docker compose up -d
   ```

6. **Update Git repository for HTTP access**

   ```bash
   docker compose exec git-server bash -c 'cd /srv/git/myindex.git && git update-server-info'
   ```

7. **Verify services are running**

   ```bash
   docker compose ps
   ```

## Configuration

### Environment Variables

All configuration is managed through environment variables in the `.env` file. The main groups are:

1. **PostgreSQL settings**
    - `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`: Database credentials
    - `POSTGRES_HOST`, `POSTGRES_PORT`: Connection settings
    - `POSTGRES_POOL_SIZE`: Connection pool size

2. **Git HTTP server settings**
    - `GIT_USER`, `GIT_PASSWORD`: Authentication credentials
    - `GIT_PORT`: Port to expose the Git HTTP server

3. **Meuse application settings**
    - `MEUSE_PORT`: HTTP port for Meuse API
    - `MEUSE_LOG_LEVEL`: Logging level
    - `MEUSE_JAVA_OPTS`: Java VM options

4. **Git index configuration**
    - `GIT_INDEX_PATH`: Path to the Git index repository
    - `GIT_TARGET`: Git branch/ref to use
    - `GIT_INDEX_URL`: URL where the Git index is available

5. **Crate storage**
    - `CRATES_PATH`: Path to store crate files

6. **Frontend settings**
    - `FRONTEND_ENABLED`: Enable or disable the frontend
    - `FRONTEND_PUBLIC`: Whether to make the frontend public
    - `FRONTEND_SECRET`: Secret key for frontend sessions

7. **Initial users**
    - `ADMIN_USER`, `ADMIN_PASSWORD`: Admin user credentials
    - `TECH_USER`, `TECH_PASSWORD`: Technical user credentials
    - `READ_USER`, `READ_PASSWORD`: Read-only user credentials

8. **Optional S3 storage**
    - `S3_ACCESS_KEY`, `S3_SECRET_KEY`: S3 credentials
    - `S3_ENDPOINT`, `S3_BUCKET`: S3 configuration

### Docker Compose Services

The deployment consists of three main services:

1. **postgres**: PostgreSQL database server
2. **git-server**: Nginx with git-http-backend for Git HTTP access
3. **meuse**: The Meuse application itself

## Volume Management

The Docker setup uses volumes for persistent data:

- **PostgreSQL data**: Stored in a named volume `pg_data`
- **Git repositories**: Stored in `./git-data` directory
- **Crate files**: Stored in `./crates` directory

## Security Considerations

1. **Passwords**: Change all default passwords in the `.env` file
2. **HTTPS**: For production, consider adding HTTPS termination
3. **Network isolation**: In production, use Docker networks to isolate services
4. **Backups**: Regularly backup the PostgreSQL data, Git repositories, and crate files

## Troubleshooting

### Common Issues

1. **Database connection errors**
    - Check if PostgreSQL is running: `docker compose ps postgres`
    - Verify database credentials in `.env`

2. **Git HTTP server issues**
    - Regenerate htpasswd: `./scripts/gen-htpasswd.sh`
    - Run git update-server-info:
      `docker compose exec git-server bash -c 'cd /srv/git/myindex.git && git update-server-info'`

3. **Meuse application errors**
    - Check logs: `docker compose logs meuse`
    - Verify configuration in `.env`

## Production Deployment

For production deployment, consider the following enhancements:

1. **Use a reverse proxy** with HTTPS termination (Nginx, Traefik)
2. **Implement regular backups** for all persistent data
3. **Set up monitoring** using Prometheus (Meuse exposes metrics)
4. **Use Docker secrets** for sensitive configuration
5. **Configure resource limits** for containers

## Upgrading

To upgrade to a new version of Meuse:

1. Pull the latest changes:
   ```bash
   git pull
   ```

2. Rebuild the Meuse image:
   ```bash
   docker compose build meuse
   ```

3. Restart the services:
   ```bash
   docker compose up -d
   ```