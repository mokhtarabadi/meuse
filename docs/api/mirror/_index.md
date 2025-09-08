---
title: Mirror
weight: 30
disableToc: false
---

As explained in the [Mirroring](/installation/mirroring/) section, Meuse can be used as a mirror for crates.io.

### Cache crates

When Meuse receives a request to download a crate from crates.io, it will automatically cache it in its local (or remote, if you use the S3 backend) store.

You can use the `cache` endpoint to prefill this store. When this API call is executed, Meuse will download the crate from crates.io and cache it. If the crate is already cached, the crate will not be downloaded again.

- **POST** /api/v1/mirror/`<crate_name>`/`<crate_version>`/cache
- Allowed users: `admin`, `tech`

---

```
curl -X POST --header "Content-Type: application/json" -H "Authorization: AhbDTCr2RHUGoUnl5ArGWl06W+UVD36hPiL2502oCpOFU/rZpPkwE7aykIpxP8Y4GDY="  localhost:8855/api/v1/mirror/log/0.4.11/cache

{"ok":true}
```


