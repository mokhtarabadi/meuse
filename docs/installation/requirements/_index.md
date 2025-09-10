---
title: Requirements
weight: 10
disableToc: false
---

## PostgreSQL

Meuse uses PostgreSQL. I run the tests using the version `11.4`, but Meuse may work with older versions.

You can also run the [postgres.sh](https://github.com/mcorbin/meuse/blob/master/postgres.sh) which will launch a PostgreSQL Docker container. Of course, don't use that in production ;)

## Java

Meuse is written in [Clojure](https://clojure.org/), you will then need Java on your computer/server to be able to run the jar. I develop Meuse/do all my tests using `OpenJDK 11`.

## Crate index

As described in the Rust [registries documentation](https://doc.rust-lang.org/nightly/cargo/reference/registries.html), the crates metadata are stored in a Git repository.

Meuse has two ways of managing the index: by shelling-out to the `git` command, or by using `JGit`, a git implementation in Java.

How to configure the crate index in Meuse is explained in the [Configuration](/installation/configuration) section of the documentation.

### shell-out to git

The index repository and the `git` command should be available in the machine running Meuse. The Meuse user should also be allowed to run git commands (push for example). You should for example add your SSH key in the SSH agent.

### JGit

The index repository should be available in the machine running Meuse. The `git` command is not needed.
