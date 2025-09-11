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

Troubleshooting

- If you get permission or authentication errors, check `git-data/htpasswd` and try cloning with `curl -u user:pass` to
  ensure HTTP auth works.
- Ensure the git http backend image you run supports `receive-pack` (push) and has `git-http-backend` enabled.
