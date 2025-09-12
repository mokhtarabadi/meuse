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

## Minimal Git Server Troubleshooting

> **Important:** If you encounter errors such as 401, 403 Forbidden, or 'pread() ... Is a directory' in nginx logs, you
> must:
>
> - Generate the htpasswd file as a host file: `./git-data/htpasswd` using the provided script (
    `./scripts/gen-htpasswd.sh`)
> - **Bind mount** the file in docker-compose (`./git-data/htpasswd:/etc/nginx/.htpasswd:ro`)
> - Never use a Docker volume for `/etc/nginx/.htpasswd` (it will be treated as a directory by nginx and fail).
> - Use a minimal `docker/git/default.conf` as:
    >
    >   ```nginx
>   server {
>     listen 80;
>     server_name _;
>     root /srv/git;
>     auth_basic "Restricted Git";
>     auth_basic_user_file /etc/nginx/.htpasswd;
>     location /myindex {
>       include fastcgi_params;
>       fastcgi_param SCRIPT_FILENAME /usr/lib/git-core/git-http-backend;
>       fastcgi_param SCRIPT_NAME /usr/lib/git-core/git-http-backend;
>       fastcgi_param GIT_PROJECT_ROOT /srv/git;
>       fastcgi_param GIT_HTTP_EXPORT_ALL "";
>       fastcgi_param PATH_INFO $uri;
>       fastcgi_param QUERY_STRING $args;
>       fastcgi_pass unix:/var/run/fcgiwrap.socket;
>       fastcgi_read_timeout 300;
>     }
>     location / {
>       try_files $uri $uri/ =404;
>     }
>   }
>   ```
>
> - To test auth, run:
    >
    >   ```sh
>   curl -u gituser:yourpw http://localhost:8180/myindex/info/refs?service=git-upload-pack
>   ```
    >   Should display Git protocol refs, not HTTP 403/500.
>
> - A successful `git clone http://gituser:yourpw@localhost:8180/myindex` proves full end-to-end registry functionality.

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

## Cleanup and Reset

To restore this project to a clean, reproducible state for the next developer or CI/build:

1. Bring down all containers and clear all volumes and networks:
   ```sh
   docker compose down -v
   ```
2. Delete any demo/test crates or ad-hoc workspace directories:
   ```sh
   rm -rf /path/to/test-crates /path/to/consume-demo /path/to/surfshield-cli /path/to/surfshield-utils
   rm -rf git-data clone-test-repo
   ```
3. Confirm a clean workspace:
   ```sh
   git status
   ```
   Only tracked files and intentional changes should remain.
4. (Optional) Prune local Docker images:
   ```sh
   docker system prune -a
   ```

See the docs for restoring/rebuilding the registry from scratch and onboarding new contributors.
