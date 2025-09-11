#!/usr/bin/env bash
set -euo pipefail

# Load .env if present
if [ -f .env ]; then
  # shellcheck disable=SC1091
  set -a; . ./.env; set +a
fi

: "${GIT_USER:?Need GIT_USER environment variable}"
: "${GIT_PASSWORD:?Need GIT_PASSWORD environment variable}"

mkdir -p git-data

# Generate htpasswd using httpd image's htpasswd utility
docker run --rm httpd:2.4 htpasswd -nb "$GIT_USER" "$GIT_PASSWORD" > git-data/htpasswd

echo "Created git-data/htpasswd (do not commit this file)"
