# Meuse, a free private Rust Registry

Meuse is a registry implementation for the [Rust](https://www.rust-lang.org) programming language.

It implements the [alternative registries](https://github.com/rust-lang/rfcs/blob/master/text/2141-alternative-registries.md) RFC and [API](https://doc.rust-lang.org/cargo/reference/registries.html), and also exposes an API to manage users, crates, tokens and categories. Meuse can store the crates binary files in various backends (filesystem, S3...).

It can also be used as a mirror for `crates.io`.

The project is open source, and the code can be found on [GitHub](https://github.com/mcorbin/meuse)

![Meuse](meuse.jpg)
<center>The Meuse county and river in France, where the troubles of the modern world disappear.</center>

---

## Bare/Non-Bare Git Repository Issue (2025-09-12)

**Root Cause:**
Meuse previously initialized its crate index Git repository as "bare" (`git init --bare`), which does
not create a working tree or index. This caused failures in JGit operations (e.g., add, commit, reset)
and rollback/publish routines, resulting in errors like:

`org.eclipse.jgit.errors.NoWorkTreeException: Bare Repository has neither a working tree, nor an index`

**Mitigation and Changes:**

- Docker entrypoint.sh now creates a non-bare repo (`git init` only)
- All code config, .env, docker-compose, YAML, scripts, and documentation updated to require and reference non-bare repo
- Runtime checks in Clojure assert against accidental bare usage, provide friendly error and guidance
- All test/scripts/dev logic updated to match new paths and expectations
- Troubleshooting docs and README entries explain fix and how to reinitialize/switch to non-bare

**Operations Advice:**

- Always use `git init` not `git init --bare` for crate index
- If you see NoWorkTreeException or related errors, your repo is bare -- reinitialize as above
- For details, consult docs/installation/docker-deployment, docs/installation/git-http-backend, and README

---
