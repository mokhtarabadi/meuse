---
title: Git HTTP Backend (nginx + htpasswd)
weight: 20
disableToc: false
---

# Git HTTP backend (nginx + htpasswd)

This document explains how to run a minimal Git HTTP server using an nginx+git-http-backend image and HTTP basic
authentication (htpasswd). This is a lightweight option to host the Cargo index for Meuse.

Files added to the repo:

- `docker-compose.git.yml` — Docker Compose service for the git HTTP server.
- `scripts/gen-htpasswd.sh` — helper script that generates `git-data/htpasswd` from `.env` using `htpasswd`.
- `.env.example` — example environment variables (username/password/port).

Important: the generated `git-data/htpasswd` contains password hashes and must NOT be committed. Keep credentials out of
version control.

Steps to set up (manual, do not start services automatically):

1. Copy the example env and set credentials:

```bash
cp .env.example .env
# Edit .env: set GIT_USER and GIT_PASSWORD
```

2. Generate the `htpasswd` file (this uses Docker to run `htpasswd`):

```bash
./scripts/gen-htpasswd.sh
```

NOTE: the repository now supports running the git server together with Postgres via the main
`docker-compose.yml`. If you prefer using that single compose file, start both services with:

```bash
docker compose up -d postgres git-server
```

If you use the combined compose, the git server will mount `./git-data` in the project root.

3. Create a workspace for repositories and initialize the index repo (example):

```bash
mkdir -p git-data
cd git-data
# create a bare repo for the Cargo index
git init --bare myindex.git
cd -
```

4. Configure Meuse to use the Git index over HTTP. In your Meuse config (e.g. `config/config.yaml` or
   `config/init_users_config.yaml`) set the metadata section:

```yaml
metadata:
  type: "shell"
  # For Meuse's local operations you can clone/push against the HTTP URL below
  url: "http://<host>:8180/myindex.git"
  # If you use a workspace clone, set path to a local clone for Meuse to operate on
  path: "/absolute/path/to/your/local/clone"
  target: "origin/master"
```

Note: Meuse needs push access to the index. If Meuse runs on a separate host, configure credentials for Meuse's user (
use a deploy account). You can encode the credentials in the URL for server-to-server pushes (e.g.
`https://user:pass@host/myindex.git`), but prefer using a credential helper or deploy user.

5. Start the git server (manual):

```bash
docker compose -f docker-compose.git.yml up -d git-server
```

6. Verify you can clone the repo (from a client machine):

```bash
git clone http://$GIT_USER@$HOST:8180/myindex.git
# or if using password prompt
git clone http://$HOST:8180/myindex.git
```

7. Configure Cargo to use the index (on developer machines):

`~/.cargo/config.toml`:

```toml
[registries.meuse]
index = "http://<host>:8180/myindex.git"
```

8. To publish via Cargo you will still need a token in `~/.cargo/credentials.toml` as usual; the Git index only provides
   crate metadata.

## Troubleshooting

If you encounter issues with the git HTTP backend, here are some common troubleshooting steps:

### Verify the htpasswd file

Make sure the `htpasswd` file is a file, not a directory. If you encounter an error in the logs about "htpasswd is a
directory", remove it and regenerate:

```bash
rm -rf git-data/htpasswd 
./scripts/gen-htpasswd.sh
```

### Enable git dumb HTTP server info

For git over HTTP to work properly, the git repository needs some extra files in the `info` directory. Run this command
to update them:

```bash
docker compose exec git-server bash -c 'cd /srv/git/myindex.git && git update-server-info'
```

### Check the nginx configuration

The git HTTP backend needs specific URL patterns to work correctly. The key part is the regular expression matching for
git HTTP protocol URLs:

```nginx
location ~ (/.*\.git/git-(upload|receive)-pack)|(/.*\.git/info/refs\?service=git-(upload|receive)-pack) {
  # configuration...  
}
```

### Test with curl

You can test the git HTTP backend using curl from inside the container:

```bash
docker compose exec git-server curl -u gituser:password http://localhost:80/myindex.git/info/refs?service=git-upload-pack
```

If this returns a git protocol response (not HTML), then the git HTTP backend is working correctly.

### Debugging git operations

If git clone or push operations fail, try adding verbose output:

```bash
GIT_CURL_VERBOSE=1 git clone http://gituser:password@localhost:8180/myindex.git
```

Publishing workflow (tokens + Cargo)

1. Create an admin token via Meuse API (replace credentials):

```bash
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"name":"admin_token","validity":365,"user":"admin","password":"admin_password"}' \
  http://localhost:8855/api/v1/meuse/token
```

2. Add the returned token to your `~/.cargo/credentials.toml`:

```toml
[registries.meuse]
token = "<token-from-response>"
```

3. Ensure your `~/.cargo/config.toml` points to the HTTP index URL:

```toml
[registries.meuse]
index = "http://<your-git-host>:8180/myindex.git"
```

4. Publish as usual:

```bash
cargo publish --registry meuse
```

This flow uses HTTP Basic auth only for git index push operations; publishing crates still requires Meuse API token for
crate uploads.
