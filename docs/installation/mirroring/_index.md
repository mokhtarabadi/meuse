---
title: Mirroring
weight: 30
disableToc: false
---

Meuse is able to mirror `crates.io`. Crates files will be downloaded from `crates.io` and cached by Meuse it its crate store.

## Create a crates.io mirror

[This article](https://gmjosack.github.io/posts/dissecting-cratesio-minimum-mirror/) is a good start to understand how it's possible to mirror `crates.io`.

First, you should fork the [crates.io-index](https://github.com/rust-lang/crates.io-index) Github project.

Once it's done, you should clone your fork: `git clone git@github.com:mcorbin/crates.io-index.git`

Then, edit the `config.json` file in the repository, and replace the `dl` and `api` keys by the Meuse URLs. For example:

```json
{
    "dl": "http://localhost:8855/api/v1/mirror",
    "api": "http://localhost:8855"
}
```

Then, edit your `~/.cargo/config` file, and add your mirror in it:

```
[registries.mirror]
index = "https://github.com/mcorbin/crates.io-index"
```

Your mirror is now ready. You should now be able to use it in your `Cargo.toml` files, for example with:

```
libc = { version = "0.2.64", registry = "mirror" }
```

Here, the crate `libc` will be downloaded from the mirror exposed by Meuse.

## How it works

When Meuse receives a request on `/api/v1/mirror` to download a crate, it will check if the crate file already exists in its store. If the file exists, Meuse will return it to the client.

If not, the request is forwarded to `crates.io`. Meuse will download the crate file, cache it in its store and then return it to the client.

![Cargo mirroring schema](/cargo_mirror1.jpg)


## Replacing crates.io by the mirror.

If you want to **always** target the Meuse mirror instead of `crates.io`, you don't have to specify `registry = "mirror"` for all your dependencies. You can add in your `~/.cargo/config` file:

```
[source.crates-io]
replace-with = 'mirror'

[source.mirror]
registry = "https://github.com/mcorbin/crates.io-index"
```

With this configuration, Cargo will automatically download crates from the Meuse mirror instead of crates.io
