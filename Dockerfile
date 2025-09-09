# Multi-stage Dockerfile for Meuse Private Rust Registry
# Stage 1: Build the application
FROM clojure:temurin-17-lein-2.9.8 AS build-env

WORKDIR /app

# Copy all source files for building
COPY . /app/

# Build the application
RUN lein uberjar

# Stage 2: Runtime image with Git fixes
FROM openjdk:17-jdk-slim

LABEL maintainer="Mohammad Mokhtarabadi <mohammad@mokhtarabadi.com>"
LABEL description="Meuse - A free private Rust registry with Git permission fixes"
LABEL version="1.4.0"

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create meuse user and group with specific UID/GID for Docker compatibility
RUN groupadd -g 999 meuse && \
    useradd -r -u 999 -g meuse -d /home/meuse -s /bin/bash -m meuse

# Set up proper home directory with correct permissions
RUN mkdir -p /home/meuse/.config && \
    chown -R meuse:meuse /home/meuse && \
    chmod 755 /home/meuse

# Create application directories with proper ownership
RUN mkdir -p /app/index /app/git-repos /app/crates /app/logs /app/config && \
    chown -R meuse:meuse /app

# Copy the built application
COPY --from=build-env --chown=meuse:meuse /app/target/uberjar/meuse-*-standalone.jar /app/meuse.jar

# Switch to meuse user for Git configuration
USER meuse

# Configure Git globally to prevent permission issues
RUN git config --global user.email "registry@meuse.local" && \
    git config --global user.name "Meuse Registry" && \
    git config --global init.defaultBranch master && \
    git config --global --add safe.directory /app/index && \
    git config --global --add safe.directory /app/git-repos/index.git && \
    git config --global --add safe.directory '*' && \
    git config --global core.autocrlf false

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 8855

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8855/healthz || exit 1

# Run application
CMD ["java", "-jar", "/app/meuse.jar"]
