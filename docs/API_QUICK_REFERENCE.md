# DMS API — Frontend Quick Reference

One-page cheat sheet for the Flutter `dms_client` team. Full docs: [API_DOCUMENTATION.md](./API_DOCUMENTATION.md) · Postman: [DMS_API.postman_collection.json](./postman/DMS_API.postman_collection.json)

## Base URL

```
http://localhost:5000/api/v1
```

**Auth header (protected routes):** `Authorization: Bearer <accessToken>`

## Response envelope

Always check `status` first (`true` = OK).

```json
{ "status": true, "statuscode": "0", "message": "...", "data": { "Array0": [] }, "jsonstring": "" }
```

Login/refresh add: `token`, `refreshToken`, `expiresAt`.

| statuscode | Meaning |
|------------|---------|
| `0` | Success |
| `1001` | Validation |
| `1002` | Not found |
| `1003` | Bad credentials |
| `1004` | Token/OTP error |
| `1005` | Locked / not approved |
| `401` / `403` | Auth / forbidden |

---

## Auth (`/auth`)

| Method | Path | Screen | Body |
|--------|------|--------|------|
| POST | `/auth/register` | `/register` | name, mobileNumber, email, panNumber, password, … |
| POST | `/auth/login` | `/login` | `{ username, password }` → saves token |
| POST | `/auth/refresh` | auto (401) | `{ refreshToken }` |
| POST | `/auth/change-password` | `/change-password` | currentPassword, newPassword |
| POST | `/auth/forgot-password` | `/forgot-password` | `{ email }` |
| POST | `/auth/verify-otp` | forgot-password step 2 | email, otp → `jsonstring` = resetToken |
| POST | `/auth/reset-password` | forgot-password step 3 | email, resetToken, newPassword, confirmPassword |

**Login username:** client PAN (`ABCDE1234F`) or `admin`.

---

## Users (`/users`) — Bearer required

| Method | Path | Screen | Notes |
|--------|------|--------|-------|
| GET | `/users/profile` | `/profile` | Current user |
| PUT | `/users/profile` | `/profile` | UpdateProfileRequest |
| GET | `/users?status=&search=` | `/admin/users` | SuperAdmin |
| POST | `/users/{id}/approval` | `/admin/users` | `{ action: "Approve"\|"Reject", comments? }` |
| POST | `/users/{id}/status?isActive=true` | `/admin/users` | SuperAdmin |
| GET | `/users/{id}` | — | Not wired in UI yet |

---

## Categories (`/categories`)

| Method | Path | Screen | Notes |
|--------|------|--------|-------|
| GET | `/categories` | upload, history, admin | `?includeInactive=false` |
| POST | `/categories` | `/admin/categories` | SuperAdmin |
| PUT | `/categories/{id}` | `/admin/categories` | SuperAdmin |
| DELETE | `/categories/{id}` | `/admin/categories` | SuperAdmin |

---

## Documents (`/documents`)

| Method | Path | Screen | Notes |
|--------|------|--------|-------|
| POST | `/documents/upload` | `/upload` | multipart: categoryId, source, file |
| GET | `/documents/history` | `/history` | ?categoryId, fromDate, toDate, searchFileName |
| GET | `/documents/dashboard` | `/dashboard` | Client only; Array0/1/2 |
| GET | `/documents/{id}/download` | `/history` | base64 in data.Array0.FileBase64 |

**Upload limits:** JPG/JPEG/PNG/PDF, 500KB–5MB.

---

## Reports (`/reports`) — SuperAdmin only

| Method | Path | Screen | Query |
|--------|------|--------|-------|
| GET | `/reports/daily` | `/admin/reports` | fromDate, toDate |
| GET | `/reports/monthly` | `/admin/reports` | year |
| GET | `/reports/user-wise` | `/admin/reports` | fromDate?, toDate? |
| GET | `/reports/category-wise` | `/admin/reports` | fromDate?, toDate? |
| GET | `/reports/audit-logs` | `/admin/reports` | fromDate?, toDate?, userId? |

---

## Flutter repository map

| File | APIs |
|------|------|
| `auth_repository.dart` | all `/auth/*` |
| `user_repository.dart` | `/users/*` |
| `category_repository.dart` | `/categories` |
| `document_repository.dart` | `/documents/*`, `/reports/*` |
| `api_response.dart` | parses `data.ArrayN`, `token`, `jsonstring` |

**Config:** `lib/core/config/app_config.dart` → `apiBaseUrl`

---

## Typical flows

### Client login → dashboard
1. `POST /auth/login` → store `token`, `refreshToken`
2. `GET /documents/dashboard` → stats + recent uploads

### Upload document
1. `GET /categories` → pick categoryId
2. `POST /documents/upload` (multipart)
3. `GET /documents/history` → refresh list

### Password reset
1. `POST /auth/forgot-password`
2. `POST /auth/verify-otp` → save `jsonstring` as resetToken
3. `POST /auth/reset-password`

### Admin approve user
1. `GET /users?status=Pending`
2. `POST /users/{id}/approval` with `{ "action": "Approve" }`
