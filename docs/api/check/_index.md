---
title: Check
weight: 30
disableToc: false
---

Meuse maintains crates states in three places:

- In the PostgreSQL database.
- In the Git repository which contains the crates metadata.
- In a directory which contains the crates binary files.

In some cases, these three places could be out of sync.

Meuse provides an API call to detect these issues.

- **GET** /api/v1/meuse/check
- Allowed users: `admin`, `tech`

---

```
curl --header "Content-Type: application/json" \
-H "Authorization: Y1B5TGx6Fevkfc/soqX2JsSh4lrME2kHy/+s10pMnT2lCaFaOF4MD9Dnso0x77rEgYY=" \
 localhost:8855/api/v1/meuse/check

[
  {
    "crate": "test1",
    "errors": [
      "metadata does not exist for version 0.1.0",
      "metata exists but not in the database for version 0.1.4",
      "crate binary file does not exist for version 0.1.1",
      "crate binary file does not exist for version 0.1.0"
    ]
  }
]

```
