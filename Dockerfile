FROM clojure:temurin-17-lein-focal as build-env

ADD . /app
WORKDIR /app

RUN lein uberjar

# -----------------------------------------------------------------------------

from eclipse-temurin:17-focal

LABEL org.opencontainers.image.title="Meuse"
LABEL org.opencontainers.image.description="A free crate registry for the Rust programming language"
LABEL org.opencontainers.image.source="https://github.com/mcorbin/meuse"
LABEL org.opencontainers.image.version="1.3.0"
LABEL org.opencontainers.image.licenses="EPL-2.0"

RUN groupadd -r meuse && useradd -r -s /bin/false -g meuse meuse
RUN mkdir /app
COPY --from=build-env /app/target/*uberjar/meuse-*-standalone.jar /app/meuse.jar

RUN chown -R meuse:meuse /app

RUN apt-get update && apt-get -y upgrade && apt-get install -y git curl
user meuse

ENTRYPOINT ["java"]

CMD ["-jar", "/app/meuse.jar"]
