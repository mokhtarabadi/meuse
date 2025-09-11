FROM clojure:temurin-17-lein-focal as build-env

ADD . /app
WORKDIR /app

RUN lein uberjar

# -----------------------------------------------------------------------------

FROM eclipse-temurin:17-focal

LABEL org.opencontainers.image.title="Meuse"
LABEL org.opencontainers.image.description="A free crate registry for the Rust programming language"
LABEL org.opencontainers.image.source="https://github.com/mcorbin/meuse"
LABEL org.opencontainers.image.version="1.3.0"
LABEL org.opencontainers.image.licenses="EPL-2.0"

# Create meuse user with explicit UID/GID 1000:1000
RUN groupadd -r -g 1000 meuse && useradd -r -u 1000 -s /bin/false -g meuse meuse
RUN mkdir -p /home/meuse/.config && chown -R meuse:meuse /home/meuse
RUN mkdir -p /app /app/git-data /app/crates /app/config
COPY --from=build-env /app/target/*uberjar/meuse-*-standalone.jar /app/meuse.jar

# Copy entrypoint script
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

RUN chown -R meuse:meuse /app

RUN apt-get update && apt-get -y upgrade && apt-get install -y git curl
USER meuse

# Expose the default Meuse port
EXPOSE 8855

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["java", "-jar", "/app/meuse.jar"]
