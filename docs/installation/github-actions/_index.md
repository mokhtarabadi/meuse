---
title: GitHub Actions
weight: 90
disableToc: false
---

# GitHub Actions Workflow

## Docker Image Build and Push

This project includes a GitHub Actions workflow that automatically builds and pushes the Docker image to GitHub
Container Registry (ghcr.io) whenever changes are pushed to the main/master branch or when a new release tag is created.

### How It Works

The workflow is defined in `.github/workflows/docker-build-push.yml` and includes the following steps:

1. Checkout the repository code
2. Extract the version number from `project.clj`
3. Login to GitHub Container Registry using the built-in GitHub token
4. Set up Docker Buildx for efficient builds
5. Extract metadata for Docker images and tags
6. Build and push the Docker image with appropriate tags
7. Generate attestation for the Docker image (enhances security)

### Image Tags

The Docker image is tagged with:

- `latest` - when pushing to the default branch (main/master)
- Version number (e.g., `1.3.0`) - extracted from the `project.clj` file

### Using the Docker Image

You can pull the Docker image from GitHub Container Registry using:

```bash
# Pull the latest version
docker pull ghcr.io/OWNER/meuse:latest

# Pull a specific version
docker pull ghcr.io/OWNER/meuse:1.3.0
```

Replace `OWNER` with the GitHub username or organization name that owns the repository.

### Manual Workflow Trigger

You can also manually trigger the workflow from the GitHub Actions tab in your repository.

### Docker Image Labels

The Docker image includes the following OpenContainers labels:

- `org.opencontainers.image.title` - "Meuse"
- `org.opencontainers.image.description` - "A free crate registry for the Rust programming language"
- `org.opencontainers.image.source` - Link to the GitHub repository
- `org.opencontainers.image.version` - Version number from project.clj
- `org.opencontainers.image.licenses` - "EPL-2.0"

These labels help with image discovery and provide important metadata about the image.