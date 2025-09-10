---
title: Statistics
weight: 35
disableToc: false
---

You can gather some statistics about Meuse with the following call.

- **GET** /api/v1/meuse/statistics
- Allowed users: `admin`, `tech`, `read-only`

---

```
curl --header "Content-Type: application/json" \
-H "Authorization: APGr3C8LrbyzNMUyO1A+4ARnFWCRg41/ZFIR/yl1hKUnL4Z8Khdbb30h/GOblwW1++g=" \
 localhost:8855/api/v1/meuse/statistics

{
  "crates": 0,
  "crates-versions": 0,
  "downloads": 0,
  "users": 1
}
```

