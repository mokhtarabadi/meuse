---
title: Launch it
weight: 20
disableToc: false
---

## Configuration path

In order to use Meuse, the `MEUSE_CONFIGURATION` variable should contain the path to the Meuse YAML file.

## From the Jar

The jars files are available on [Github](https://github.com/mcorbin/meuse/releases). The jars are built using OpenJDK 11.

```
java -jar meuse.jar
```

## Using Leiningen

`lein run` should work. the configuration used is the file `dev/resources/config.yaml`.
