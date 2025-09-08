---
title: User and role
weight: 10
disableToc: false
---

## Roles

In Meuse, an user one (and only one) role assigned to it. Only 2 roles exists, and it's not possible to create new roles:

- `admin`: An admin can do anything (except creating tokens for another user).
- `tech`: Some calls are not allowed for tech users. Some parameters are also only usable by an admin account. This role should be perfect for a CI user.
- `read-only`: Read-only users.

### Create a new user

- **POST** /api/v1/meuse/user
- Allowed users: `admin`

| Field | Type | Description |
| ------ | ----------- | ----------- |
| active    | boolean | Initial status of the user. |
| description | string | The description of the user. |
| name    | string | The user name. |
| password | string | The user password. It should have at least 8 characters. |
| role    |  string | The user role. Should be `admin`, `tech` or `read-only` |

---

```
 curl --header "Content-Type: application/json" --request POST \
-H "Authorization: HhqLVFVvTzi+sY0ewvjnVwWnbPmdTOTOZoDJniBVDoJoDWxxU1tvqa0sASWGGorMjJY=" \
--data '{"active":true,"description":"new user","name":"newuser","password":"securepassword","role":"tech"}' \
 localhost:8855/api/v1/meuse/user

{"ok":true}
```

### Update an user

An user can update its own accout, but only an `admin` can update another account.

- **POST** /api/v1/meuse/user/`<user_name>`
- Allowed users: `admin`, `tech`, `read-only`

| Field | Type | Description |
| ------ | ----------- | ----------- |
| active    | boolean | Initial status of the user. **Admin only** |
| description | string | The description of the user. |
| password | string | The user password. It should have at least 8 characters. |
| role    |  string | The user role. Should be `admin`, `tech` or `read-only`. **Admin only** |

---

```
 curl --header "Content-Type: application/json" --request POST \
-H "Authorization: Y1B5TGx6Fevkfc/soqX2JsSh4lrME2kHy/+s10pMnT2lCaFaOF4MD9Dnso0x77rEgYY=" \
--data '{"description":"updated user","password":"securepassword"}' \
 localhost:8855/api/v1/meuse/user/root_user

{"ok":true}
```

### Delete an user

- **DELETE** /api/v1/meuse/user/`<user_name>`
- Allowed users: `admin`

---

```
 curl --header "Content-Type: application/json" --request DELETE \
-H "Authorization: HhqLVFVvTzi+sY0ewvjnVwWnbPmdTOTOZoDJniBVDoJoDWxxU1tvqa0sASWGGorMjJY=" \
 localhost:8855/api/v1/meuse/user/newuser

{"ok":true}
```

### List users

- **GET** /api/v1/meuse/user
- Allowed users: `admin`

---

```
 curl --header "Content-Type: application/json" \
-H "Authorization: Y1B5TGx6Fevkfc/soqX2JsSh4lrME2kHy/+s10pMnT2lCaFaOF4MD9Dnso0x77rEgYY=" \
 localhost:8855/api/v1/meuse/user

{
  "users": [
    {
      "id": "f3e6888e-97f9-11e9-ae4e-ef296f05cd17",
      "name": "root_user",
      "description": "updated user",
      "active": true,
      "role": "admin"
    }
  ]
}
```
