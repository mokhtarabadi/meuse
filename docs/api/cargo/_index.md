---
title: Cargo
weight: 4
disableToc: false
---

## The Cargo API

You can interact with Meuse using Cargo (exactly like `crates.io`). Meuse fully implements the [alternative registries](https://github.com/rust-lang/rfcs/blob/master/text/2141-alte) RFC and [API](https://doc.rust-lang.org/cargo/reference/registries.html).

The commands `cargo publish`, `cargo yank`, `cargo owner`, `cargo search` should work with Meuse.

Cargo can also fetches dependencies from Meuse if you configure the `registry` option for your dependency.

### Cargo publish

- The command will fail if a category does not exist.
- An `admin` or `tech` user can publish a `new` create. In that case, the user will automatically own the crate. If an user try to publish a new `version` of a crate without being an owner, the command will fail.

### Cargo yank

Only owners of a crate can use this command.

### Cargo owner

Only owners of a crate can add or remove an owner.
