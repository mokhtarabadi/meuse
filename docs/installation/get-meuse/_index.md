---
title: Get or build Meuse
weight: 15
disableToc: false
---

## Download a release from Github

You can download a release from [Github](https://github.com/mcorbin/meuse/releases).

## Build Meuse

In order to build Meuse, you need to install [Leiningen](https://leiningen.org/). You should also set the environment variable `LEIN_SNAPSHOTS_IN_RELEASE` to `true`.

Then, clone the Meuse repository and execute `lein uberjar`. The resulting jar will be `target/uberjar/meuse-<version>-standalone.jar`.

## Build Meuse Docker image

The `Dockerfile` file at the root of the Meuse repository will build Meuse using `leiningen`, an then build an image which will contain the jar and launch the project.
