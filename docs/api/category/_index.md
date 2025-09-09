---
title: Category
weight: 15
disableToc: false
---

### Create a new category

- **POST** /api/v1/meuse/category
- Allowed users: `admin`

| Field | Type | Description |
| ------ | ----------- | ----------- |
| description | string | The description of the category. |
| name    | string | The category name. |

---

```
 curl --header "Content-Type: application/json"  --request POST \
-H "Authorization: HhqLVFVvTzi+sY0ewvjnVwWnbPmdTOTOZoDJniBVDoJoDWxxU1tvqa0sASWGGorMjJY=" \
--data '{"description":"email category","name":"email"}' \
 localhost:8855/api/v1/meuse/category

{"ok":true}
```

### Update a category

- **GET** /api/v1/meuse/category/`<category_name>`
- Allowed users: `admin`

| Field | Type | Description |
| ------ | ----------- | ----------- |
| description | string | The description of the category. |
| name    | string | The category name. |

---

```
 curl --header "Content-Type: application/json"  --request POST \
-H "Authorization: Y1B5TGx6Fevkfc/soqX2JsSh4lrME2kHy/+s10pMnT2lCaFaOF4MD9Dnso0x77rEgYY=" \
--data '{"description":"system category","name":"system"}' \
localhost:8855/api/v1/meuse/category/email

{"ok":true}
```

### List categories

- **GET** /api/v1/meuse/category
- Allowed users: `admin`, `tech`, `read-only`

---

```
curl --header "Content-Type: application/json"  \
-H "Authorization: Y1B5TGx6Fevkfc/soqX2JsSh4lrME2kHy/+s10pMnT2lCaFaOF4MD9Dnso0x77rEgYY=" \
localhost:8855/api/v1/meuse/category

{
  "categories": [
    {
      "id": "4e9cbfcd-4f7e-46f1-a3ff-c9af7cc57137",
      "name": "email",
      "description": "email category"
    }
  ]
}
```
