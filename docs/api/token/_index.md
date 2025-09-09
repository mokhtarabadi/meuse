---
title: Token
weight: 1
disableToc: false
---

### Create a new token

- **POST** /api/v1/meuse/token
- Allowed users: `admin`, `tech`, `read-only`

| Field | Type | Description |
| ------ | ----------- | ----------- |
| name    | string | The name of the token. |
| password | string | The user password. |
| user    | string | The user name. |
| validity | int | The token will be valid for `validity` days. |

---

```
curl --header "Content-Type: application/json" --request POST \
--data '{"name":"test_token","validity":10,"user":"root_user","password":"do_not_use_this_password"}' \
localhost:8855/api/v1/meuse/token

{"token":"HhqLVFVvTzi+sY0ewvjnVwWnbPmdTOTOZoDJniBVDoJoDWxxU1tvqa0sASWGGorMjJY="}
```

### Delete a token

Users can delete their own tokens. An `admin` can delete tokens for other users.

- **DELETE** /api/v1/meuse/token
- Allowed users: `admin`, `tech`, `read-only`

| Field | Type | Description |
| ------ | ----------- | ----------- |
| name    | string | The name of the token. |
| user    | string | The user name. |

---

```
curl --header "Content-Type: application/json" --request DELETE \
-H "Authorization: HhqLVFVvTzi+sY0ewvjnVwWnbPmdTOTOZoDJniBVDoJoDWxxU1tvqa0sASWGGorMjJY=" \
--data '{"name":"test_token2","user":"root_user"}' \
localhost:8855/api/v1/meuse/token

{"ok":true}
```

### List tokens

- **GET** /api/v1/meuse/token
- Allowed users: `admin`, `tech`, `read-only`

Admin users can pass an `user` parameter in the request url (for example, `/api/v1/meuse/token?user=foo`) to list tokens for a specific user.

---

```
curl --header "Content-Type: application/json" \
-H "Authorization: Y1B5TGx6Fevkfc/soqX2JsSh4lrME2kHy/+s10pMnT2lCaFaOF4MD9Dnso0x77rEgYY=" \
 localhost:8855/api/v1/meuse/token

{
  "tokens": [
    {
      "id": "b2978e5f-c312-4389-98eb-932ab1785265",
      "name": "test_token",
      "created-at": "2019-07-30T20:17:34Z",
      "expired-at": "2019-08-09T20:17:34Z",
      "last-used-at":"2020-09-08T21:27:12Z"
    }
  ]
}
```
