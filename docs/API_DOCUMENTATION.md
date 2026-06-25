# DMS API Documentation

Document Management System (DMS) REST API reference for frontend integration.

**API version:** `v1`  
**Base URL (development):** `http://localhost:5000/api/v1`  
**Base URL (HTTPS):** `https://localhost:5001/api/v1`  
**Interactive docs:** Swagger UI at `/swagger` (Development environment only)

**Related resources:**
- [API Quick Reference](./API_QUICK_REFERENCE.md) — one-page cheat sheet for frontend developers
- [Postman Collection](./postman/DMS_API.postman_collection.json) — import into Postman/Insomnia for live testing

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [Standard Response Envelope](#standard-response-envelope)
4. [Status Codes](#status-codes)
5. [Roles & Authorization](#roles--authorization)
6. [Frontend Integration Map](#frontend-integration-map)
7. [Auth APIs](#auth-apis)
8. [Users APIs](#users-apis)
9. [Categories APIs](#categories-apis)
10. [Documents APIs](#documents-apis)
11. [Reports APIs](#reports-apis)
12. [Error Handling](#error-handling)
13. [Rate Limiting](#rate-limiting)

---

## Overview

The DMS backend is an ASP.NET Core API that manages user registration/approval, document uploads, categories, and admin reporting. All endpoints (except public auth routes) require a valid JWT Bearer token.

| Item | Value |
|------|-------|
| Content-Type (JSON) | `application/json` |
| Content-Type (upload) | `multipart/form-data` |
| API versioning | URL segment: `/api/v{version}/...` |
| CORS | All origins allowed (`DmsClients` policy) |

---

## Authentication

### Obtaining a token

Call `POST /auth/login` with PAN (client) or `admin` (SuperAdmin) credentials. The response is a `TokenResponse` containing:

| Field | Description |
|-------|-------------|
| `token` | JWT access token (default expiry: 60 minutes) |
| `refreshToken` | Opaque refresh token (valid 7 days) |
| `expiresAt` | Access token UTC expiry |
| `data.Array0` | Logged-in user profile |

### Using a token

Include the access token on every protected request:

```http
Authorization: Bearer <access_token>
```

### Refreshing a token

When the access token expires (or a `401` is returned), call `POST /auth/refresh` with the stored `refreshToken`. The auth interceptor in the Flutter client handles this automatically.

### Default admin credentials (seed data)

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | `Admin@123` |

> Change these credentials in production.

---

## Standard Response Envelope

Every endpoint returns a `Response` object (auth login/refresh returns `TokenResponse`, which extends `Response`).

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [ /* primary result set */ ],
    "Array1": [ /* optional second result set */ ],
    "Array2": [ /* optional third result set */ ]
  },
  "jsonstring": ""
}
```

### Field reference

| Field | Type | Description |
|-------|------|-------------|
| `status` | `boolean` | `true` = success, `false` = failure |
| `statuscode` | `string` | `"0"` on success; see [Status Codes](#status-codes) for errors |
| `message` | `string` | Human-readable message |
| `data` | `object` | Named arrays (`Array0`, `Array1`, …) from stored procedure result sets |
| `jsonstring` | `string` | Scalar payload: new record ID, reset token, etc. |

### TokenResponse (login / refresh)

Adds top-level token fields:

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Login successful.",
  "token": "<jwt>",
  "refreshToken": "<opaque_refresh_token>",
  "expiresAt": "2026-06-25T12:00:00Z",
  "data": { "Array0": [ { /* user */ } ] },
  "jsonstring": ""
}
```

> **Frontend note:** Property names in `data.ArrayN` may be PascalCase from SQL; the Flutter client normalizes them to camelCase before parsing.

---

## Status Codes

| `statuscode` | Meaning |
|--------------|---------|
| `0` | Success |
| `1001` | Validation error |
| `1002` | Resource not found |
| `1003` | Invalid credentials |
| `1004` | Token / OTP error |
| `1005` | Account locked or not approved |
| `401` | Missing or invalid user identity |
| `403` | Forbidden (role/ownership check failed) |
| `500` | Internal server error |

---

## Roles & Authorization

| Role | Description |
|------|-------------|
| `SuperAdmin` | Full admin access: users, categories, reports, all document history |
| `Client` | Upload documents, view own history/dashboard, manage own profile |

| Endpoint pattern | Auth |
|------------------|------|
| `POST /auth/register`, `login`, `refresh`, `forgot-password`, `verify-otp`, `reset-password` | Public |
| `POST /auth/change-password` | Any authenticated user |
| `GET/PUT /users/profile` | Any authenticated user |
| `GET /users`, `POST /users/{id}/approval`, `POST /users/{id}/status` | SuperAdmin only |
| `GET /users/{id}` | SuperAdmin, or Client viewing own ID |
| `GET/POST/PUT/DELETE /categories` | Authenticated; write ops SuperAdmin only |
| `GET /documents/history` | Authenticated; Client auto-scoped to own uploads |
| `GET /documents/dashboard` | Client only |
| `POST /documents/upload`, `GET /documents/{id}/download` | Any authenticated user |
| All `/reports/*` | SuperAdmin only |

---

## Frontend Integration Map

The primary consumer of these APIs is the Flutter app at **`DMS_ClientApp/dms_client`**.

A separate Flutter project (`DMS_Client`) uses **Firebase/Firestore** and does **not** call this .NET API.

| API | HTTP | Frontend route / screen | Repository / provider |
|-----|------|-------------------------|----------------------|
| `POST /auth/login` | POST | `/login` → `LoginScreen` | `AuthRepository.login` → `authProvider` |
| `POST /auth/register` | POST | `/register` → `RegisterScreen` | `AuthRepository.register` |
| `POST /auth/refresh` | POST | Auto (session restore, 401 retry) | `AuthInterceptor`, `AuthRepository.restoreSession` |
| `POST /auth/change-password` | POST | `/change-password` → `ChangePasswordScreen` | `AuthRepository.changePassword` |
| `POST /auth/forgot-password` | POST | `/forgot-password` → `PasswordRecoveryScreen` | `AuthRepository.forgotPassword` |
| `POST /auth/verify-otp` | POST | `/forgot-password` (OTP step) | `AuthRepository.verifyOtp` |
| `POST /auth/reset-password` | POST | `/forgot-password` (reset step) | `AuthRepository.resetPassword` |
| `GET /users/profile` | GET | `/profile`, session restore | `UserRepository.getProfile` → `authProvider.refreshProfile` |
| `PUT /users/profile` | PUT | `/profile` → `ProfileScreen` | `UserRepository.updateProfile` |
| `GET /users` | GET | `/admin/users` → `UserManagementScreen` | `UserRepository.getUsers` |
| `POST /users/{id}/approval` | POST | `/admin/users` (approve/reject dialogs) | `UserRepository.approveReject` |
| `POST /users/{id}/status` | POST | `/admin/users` (activate/deactivate) | `UserRepository.setStatus` |
| `GET /users/{id}` | GET | *(not wired in current frontend)* | Available for future detail views |
| `GET /categories` | GET | `/upload`, `/history`, `/admin/categories` | `CategoryRepository.getAll` → `categoryProvider` |
| `POST /categories` | POST | `/admin/categories` → `CategoryManagementScreen` | `CategoryRepository.create` |
| `PUT /categories/{id}` | PUT | `/admin/categories` | `CategoryRepository.update` |
| `DELETE /categories/{id}` | DELETE | `/admin/categories` | `CategoryRepository.delete` |
| `POST /documents/upload` | POST | `/upload` → `UploadDocumentScreen` | `DocumentRepository.upload` → `documentProvider` |
| `GET /documents/history` | GET | `/history` → `HistoryScreen` | `DocumentRepository.getHistory` |
| `GET /documents/dashboard` | GET | `/dashboard` → `ClientDashboardScreen` | `DocumentRepository.getDashboard` → `dashboardProvider` |
| `GET /documents/{id}/download` | GET | `/history` (download action) | `DocumentRepository.download` |
| `GET /reports/daily` | GET | `/admin/reports` → `ReportsScreen` | `DocumentRepository.getDailyReport` |
| `GET /reports/monthly` | GET | `/admin/reports` | `DocumentRepository.getMonthlyReport` |
| `GET /reports/user-wise` | GET | `/admin/reports` | `DocumentRepository.getUserWiseReport` |
| `GET /reports/category-wise` | GET | `/admin/reports` | `DocumentRepository.getCategoryWiseReport` |
| `GET /reports/audit-logs` | GET | `/admin/reports` (audit tab) | `DocumentRepository.getAuditLogs` |

---

## Auth APIs

Base path: `/api/v1/auth`

---

### POST `/auth/register`

Register a new client. Account enters **Pending** status until a SuperAdmin approves it.

**Auth:** None  
**Frontend:** `RegisterScreen` (`/register`)

#### Request

```http
POST /api/v1/auth/register
Content-Type: application/json
```

```json
{
  "name": "Rajesh Kumar",
  "mobileNumber": "9876543210",
  "email": "rajesh@example.com",
  "panNumber": "ABCDE1234F",
  "password": "Secure@123",
  "address": "123 MG Road, Mumbai",
  "businessName": "Kumar Traders",
  "contactPersonName": "Rajesh Kumar",
  "gstNumber": "27ABCDE1234F1Z5"
}
```

| Field | Required | Rules |
|-------|----------|-------|
| `name` | Yes | Non-empty |
| `mobileNumber` | Yes | 10 digits, starts with 6–9 |
| `email` | Yes | Valid email format |
| `panNumber` | Yes | `AAAAA9999A` format |
| `password` | Yes | Min 8 chars, upper, lower, digit, special |
| `address`, `businessName`, `contactPersonName`, `gstNumber` | No | GST must match Indian GST format if provided |

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Registration successful. You will be notified by email once an administrator approves your account.",
  "data": null,
  "jsonstring": "42"
}
```

`jsonstring` contains the new `userId`.

#### Error response (validation)

```json
{
  "status": false,
  "statuscode": "1001",
  "message": "Invalid mobile number.; Invalid PAN number.",
  "data": null,
  "jsonstring": ""
}
```

---

### POST `/auth/login`

Authenticate with PAN (clients) or `admin` (SuperAdmin).

**Auth:** None  
**Frontend:** `LoginScreen` (`/login`), `SplashScreen` (session restore via refresh)

#### Request

```http
POST /api/v1/auth/login
Content-Type: application/json
```

```json
{
  "username": "ABCDE1234F",
  "password": "Secure@123"
}
```

| Field | Description |
|-------|-------------|
| `username` | Client PAN number (e.g. `ABCDE1234F`) or `admin` |
| `password` | Plain-text password |

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Login successful.",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "k8fJ3xP9mN2vL7qR...",
  "expiresAt": "2026-06-25T11:30:00Z",
  "data": {
    "Array0": [
      {
        "UserId": 42,
        "Name": "Rajesh Kumar",
        "Email": "rajesh@example.com",
        "MobileNumber": "9876543210",
        "BusinessName": "Kumar Traders",
        "RoleName": "Client",
        "UserStatus": "Approved",
        "ProfileCompleted": true
      }
    ]
  },
  "jsonstring": ""
}
```

#### Error responses

Invalid credentials:

```json
{
  "status": false,
  "statuscode": "1003",
  "message": "Invalid username or password.",
  "data": null,
  "jsonstring": ""
}
```

Account locked (5 failed attempts, 30-minute lockout):

```json
{
  "status": false,
  "statuscode": "1005",
  "message": "Account is locked. Try again after 30 minutes.",
  "data": null,
  "jsonstring": ""
}
```

---

### POST `/auth/refresh`

Issue a new access token using a valid refresh token. The old refresh token is revoked.

**Auth:** None  
**Frontend:** `AuthInterceptor` (on 401), `AuthRepository.restoreSession`

#### Request

```json
{
  "refreshToken": "k8fJ3xP9mN2vL7qR..."
}
```

#### Success response

Same shape as [login success](#post-authlogin).

#### Error response

```json
{
  "status": false,
  "statuscode": "1004",
  "message": "Invalid or expired refresh token.",
  "data": null,
  "jsonstring": ""
}
```

---

### POST `/auth/change-password`

Change password for the currently authenticated user.

**Auth:** Bearer token  
**Frontend:** `ChangePasswordScreen` (`/change-password`)

#### Request

```json
{
  "currentPassword": "Secure@123",
  "newPassword": "NewSecure@456"
}
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Password changed successfully.",
  "data": null,
  "jsonstring": ""
}
```

---

### POST `/auth/forgot-password`

Request an OTP email for password recovery. Always returns the same message (does not reveal whether the email exists).

**Auth:** None  
**Frontend:** `PasswordRecoveryScreen` — step 1

#### Request

```json
{
  "email": "rajesh@example.com"
}
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "If the email exists, an OTP has been sent to your registered email.",
  "data": null,
  "jsonstring": ""
}
```

---

### POST `/auth/verify-otp`

Verify the emailed OTP and receive a short-lived reset token.

**Auth:** None  
**Frontend:** `PasswordRecoveryScreen` — step 2

#### Request

```json
{
  "email": "rajesh@example.com",
  "otp": "482910"
}
```

| Field | Rules |
|-------|-------|
| `otp` | 6-digit numeric (configurable via `Notifications:OtpLength`) |

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "OTP verified. You may now set a new password.",
  "data": null,
  "jsonstring": "dGhpcyBpcyBhIGJhc2U2NCByZXNldCB0b2tlbg=="
}
```

`jsonstring` is the `resetToken` — pass it to `/auth/reset-password` within 15 minutes.

#### Error response (invalid OTP)

```json
{
  "status": false,
  "statuscode": "1004",
  "message": "Invalid OTP. 4 attempt(s) remaining.",
  "data": null,
  "jsonstring": ""
}
```

---

### POST `/auth/reset-password`

Set a new password after OTP verification.

**Auth:** None  
**Frontend:** `PasswordRecoveryScreen` — step 3

#### Request

```json
{
  "email": "rajesh@example.com",
  "resetToken": "dGhpcyBpcyBhIGJhc2U2NCByZXNldCB0b2tlbg==",
  "newPassword": "NewSecure@456",
  "confirmPassword": "NewSecure@456"
}
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Password reset successfully. Please sign in with your new password.",
  "data": null,
  "jsonstring": ""
}
```

---

## Users APIs

Base path: `/api/v1/users`  
**Auth:** Bearer token (role restrictions apply)

---

### GET `/users`

List users with optional filters. SuperAdmin only.

**Frontend:** `UserManagementScreen` (`/admin/users`)

#### Request

```http
GET /api/v1/users?status=Pending&search=rajesh
Authorization: Bearer <token>
```

| Query param | Description |
|-------------|-------------|
| `status` | Filter by `UserStatus` (e.g. `Pending`, `Approved`, `Active`, `Rejected`) |
| `search` | Search name, email, mobile, PAN |

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "UserId": 42,
        "Name": "Rajesh Kumar",
        "MobileNumber": "9876543210",
        "Email": "rajesh@example.com",
        "PANNumber": "ABCDE1234F",
        "Address": "123 MG Road",
        "BusinessName": "Kumar Traders",
        "ContactPersonName": "Rajesh Kumar",
        "GSTNumber": "27ABCDE1234F1Z5",
        "Username": "ABCDE1234F",
        "UserStatus": "Pending",
        "ProfileCompleted": true,
        "IsActive": true,
        "RoleName": "Client",
        "CreatedDate": "2026-06-20T08:15:00"
      }
    ]
  },
  "jsonstring": ""
}
```

---

### GET `/users/{id}`

Get a single user by ID. SuperAdmin can view any user; Client can only view their own ID.

**Frontend:** Not currently used (available for detail modals / admin drill-down).

#### Request

```http
GET /api/v1/users/42
Authorization: Bearer <token>
```

#### Success response

Same user object as list, wrapped in `data.Array0` (single row).

#### Error response (client accessing another user)

```json
{
  "status": false,
  "statuscode": "403",
  "message": "Access denied.",
  "data": null,
  "jsonstring": ""
}
```

---

### GET `/users/profile`

Get the authenticated user's profile.

**Frontend:** `ProfileScreen`, `authProvider.refreshProfile`

#### Request

```http
GET /api/v1/users/profile
Authorization: Bearer <token>
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "UserId": 42,
        "Name": "Rajesh Kumar",
        "MobileNumber": "9876543210",
        "Email": "rajesh@example.com",
        "PANNumber": "ABCDE1234F",
        "Address": "123 MG Road",
        "BusinessName": "Kumar Traders",
        "ContactPersonName": "Rajesh Kumar",
        "GSTNumber": "27ABCDE1234F1Z5",
        "Username": "ABCDE1234F",
        "UserStatus": "Approved",
        "ProfileCompleted": true,
        "IsActive": true,
        "RoleName": "Client",
        "CreatedDate": "2026-06-20T08:15:00"
      }
    ]
  },
  "jsonstring": ""
}
```

---

### PUT `/users/profile`

Update the authenticated user's profile.

**Frontend:** `ProfileScreen` (`/profile`)

#### Request

```json
{
  "name": "Rajesh Kumar",
  "mobileNumber": "9876543210",
  "email": "rajesh@example.com",
  "address": "456 Park Street, Mumbai",
  "businessName": "Kumar Traders Pvt Ltd",
  "contactPersonName": "Rajesh Kumar",
  "gstNumber": "27ABCDE1234F1Z5",
  "profileCompleted": true
}
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Profile updated successfully.",
  "data": null,
  "jsonstring": ""
}
```

---

### POST `/users/{id}/approval`

Approve or reject a pending user. SuperAdmin only.

**Frontend:** `UserManagementScreen` — approve/reject dialogs

#### Request

```json
{
  "action": "Approve",
  "comments": "Documents verified"
}
```

| Field | Values |
|-------|--------|
| `action` | `"Approve"` or `"Reject"` |
| `comments` | Optional rejection/approval notes |

#### Success response (approve)

```json
{
  "status": true,
  "statuscode": "0",
  "message": "User approved. They can sign in with their PAN number and the password chosen at registration.",
  "data": null,
  "jsonstring": ""
}
```

#### Success response (reject)

```json
{
  "status": true,
  "statuscode": "0",
  "message": "User rejected.",
  "data": null,
  "jsonstring": ""
}
```

---

### POST `/users/{id}/status`

Activate or deactivate a user. SuperAdmin only.

**Frontend:** `UserManagementScreen` — toggle active status

#### Request

```http
POST /api/v1/users/42/status?isActive=false
Authorization: Bearer <token>
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "User deactivated successfully.",
  "data": null,
  "jsonstring": ""
}
```

---

## Categories APIs

Base path: `/api/v1/categories`  
**Auth:** Bearer token

---

### GET `/categories`

List document categories.

**Frontend:** `UploadDocumentScreen`, `HistoryScreen` (filter dropdown), `CategoryManagementScreen`

#### Request

```http
GET /api/v1/categories?includeInactive=false
Authorization: Bearer <token>
```

| Query param | Default | Description |
|-------------|---------|-------------|
| `includeInactive` | `false` | Include deactivated categories (SuperAdmin only; forced `false` for other roles) |

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "CategoryId": 1,
        "CategoryName": "Sales Documents",
        "Description": "Sales related documents",
        "IsActive": true
      },
      {
        "CategoryId": 2,
        "CategoryName": "GST Documents",
        "Description": "GST related documents",
        "IsActive": true
      }
    ]
  },
  "jsonstring": ""
}
```

---

### POST `/categories`

Create a category. SuperAdmin only.

**Frontend:** `CategoryManagementScreen` (`/admin/categories`)

#### Request

```json
{
  "categoryName": "Invoice Documents",
  "description": "Customer and vendor invoices"
}
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Category created successfully.",
  "data": null,
  "jsonstring": "6"
}
```

---

### PUT `/categories/{id}`

Update a category. SuperAdmin only.

**Frontend:** `CategoryManagementScreen`

#### Request

```json
{
  "categoryName": "Invoice Documents",
  "description": "Updated description"
}
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Category updated successfully.",
  "data": null,
  "jsonstring": ""
}
```

---

### DELETE `/categories/{id}`

Soft-delete (deactivate) a category. SuperAdmin only.

**Frontend:** `CategoryManagementScreen`

#### Request

```http
DELETE /api/v1/categories/6
Authorization: Bearer <token>
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Category deleted successfully.",
  "data": null,
  "jsonstring": ""
}
```

---

## Documents APIs

Base path: `/api/v1/documents`  
**Auth:** Bearer token

---

### POST `/documents/upload`

Upload a document file.

**Frontend:** `UploadDocumentScreen` (`/upload`)

#### Request

```http
POST /api/v1/documents/upload
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

| Form field | Type | Description |
|------------|------|-------------|
| `categoryId` | `int` | Category ID from `GET /categories` |
| `source` | `string` | Upload source label (e.g. `"Web"`, `"Mobile"`) |
| `file` | `file` | Document file |

**File constraints:**

| Rule | Value |
|------|-------|
| Allowed types | `.jpg`, `.jpeg`, `.png`, `.pdf` |
| Size | 500 KB – 5 MB |

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Document uploaded successfully.",
  "data": {
    "Array0": [
      {
        "fileId": "101",
        "fileName": "42_20260625103000_a1b2c3d4.pdf",
        "originalFileName": "gst-return-may.pdf",
        "fileExtension": ".pdf",
        "fileSize": 1048576,
        "contentType": "application/pdf"
      }
    ]
  },
  "jsonstring": "101"
}
```

#### Error response (invalid file type)

```json
{
  "status": false,
  "statuscode": "1001",
  "message": "File type not allowed. Supported: JPG, JPEG, PNG, PDF.",
  "data": null,
  "jsonstring": ""
}
```

---

### GET `/documents/history`

Query document upload history with filters.

**Frontend:** `HistoryScreen` (`/history`)

For **Client** role, `clientId` is automatically set to the logged-in user — they cannot view other clients' documents.

#### Request

```http
GET /api/v1/documents/history?categoryId=2&fromDate=2026-06-01&toDate=2026-06-25&searchFileName=gst
Authorization: Bearer <token>
```

| Query param | Description |
|-------------|-------------|
| `clientId` | Filter by client (SuperAdmin only; ignored for Client role) |
| `categoryId` | Filter by category |
| `fromDate` | ISO 8601 start date |
| `toDate` | ISO 8601 end date |
| `searchFileName` | Partial filename search |

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "FileId": 101,
        "ClientId": 42,
        "CategoryId": 2,
        "CategoryName": "GST Documents",
        "FileName": "42_20260625103000_a1b2c3d4.pdf",
        "OriginalFileName": "gst-return-may.pdf",
        "FileExtension": ".pdf",
        "FileSize": 1048576,
        "Source": "Web",
        "DocumentStatus": "Pending",
        "UploadDate": "2026-06-25T10:30:00",
        "ClientName": "Rajesh Kumar",
        "BusinessName": "Kumar Traders"
      }
    ]
  },
  "jsonstring": ""
}
```

> `FilePath` is intentionally excluded from API responses. Downloads use base64 via the download endpoint.

---

### GET `/documents/dashboard`

Client dashboard: profile summary, document stats, and recent uploads.

**Auth:** Client role only  
**Frontend:** `ClientDashboardScreen` (`/dashboard`)

#### Request

```http
GET /api/v1/documents/dashboard
Authorization: Bearer <token>
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "Name": "Rajesh Kumar",
        "BusinessName": "Kumar Traders"
      }
    ],
    "Array1": [
      {
        "TotalDocuments": 15,
        "PendingDocuments": 3,
        "ApprovedDocuments": 12
      }
    ],
    "Array2": [
      {
        "FileId": 101,
        "ClientId": 42,
        "CategoryId": 2,
        "CategoryName": "GST Documents",
        "FileName": "42_20260625103000_a1b2c3d4.pdf",
        "OriginalFileName": "gst-return-may.pdf",
        "FileExtension": ".pdf",
        "FileSize": 1048576,
        "Source": "Web",
        "DocumentStatus": "Pending",
        "UploadDate": "2026-06-25T10:30:00"
      }
    ]
  },
  "jsonstring": ""
}
```

| Array | Content |
|-------|---------|
| `Array0` | User info (name, businessName) |
| `Array1` | Stats (totalDocuments, pendingDocuments, approvedDocuments) |
| `Array2` | Recent uploads (document list) |

---

### GET `/documents/{id}/download`

Download a document as base64-encoded content in the JSON response.

**Frontend:** `HistoryScreen` — download button

#### Request

```http
GET /api/v1/documents/101/download
Authorization: Bearer <token>
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Document retrieved successfully.",
  "data": {
    "Array0": [
      {
        "FileId": 101,
        "FileName": "42_20260625103000_a1b2c3d4.pdf",
        "OriginalFileName": "gst-return-may.pdf",
        "FileExtension": ".pdf",
        "FileSize": 1048576,
        "ContentType": "application/pdf",
        "FileBase64": "JVBERi0xLjQKJeLjz9MK..."
      }
    ]
  },
  "jsonstring": ""
}
```

Decode `FileBase64` to bytes for file save/display.

#### Error response

```json
{
  "status": false,
  "statuscode": "1002",
  "message": "Document not found.",
  "data": null,
  "jsonstring": ""
}
```

---

## Reports APIs

Base path: `/api/v1/reports`  
**Auth:** SuperAdmin only  
**Frontend:** `ReportsScreen` (`/admin/reports`)

---

### GET `/reports/daily`

Daily upload counts within a date range.

#### Request

```http
GET /api/v1/reports/daily?fromDate=2026-06-01&toDate=2026-06-25
Authorization: Bearer <token>
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "UploadDay": "2026-06-25",
        "DocumentCount": 8,
        "TotalSize": 12582912
      },
      {
        "UploadDay": "2026-06-24",
        "DocumentCount": 5,
        "TotalSize": 7340032
      }
    ]
  },
  "jsonstring": ""
}
```

---

### GET `/reports/monthly`

Monthly upload counts for a given year.

#### Request

```http
GET /api/v1/reports/monthly?year=2026
Authorization: Bearer <token>
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "UploadMonth": "2026-06",
        "DocumentCount": 45,
        "TotalSize": 67108864
      },
      {
        "UploadMonth": "2026-05",
        "DocumentCount": 38,
        "TotalSize": 52428800
      }
    ]
  },
  "jsonstring": ""
}
```

---

### GET `/reports/user-wise`

Upload statistics grouped by client.

#### Request

```http
GET /api/v1/reports/user-wise?fromDate=2026-01-01&toDate=2026-06-25
Authorization: Bearer <token>
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "UserId": 42,
        "Name": "Rajesh Kumar",
        "BusinessName": "Kumar Traders",
        "DocumentCount": 15,
        "TotalSize": 15728640
      }
    ]
  },
  "jsonstring": ""
}
```

---

### GET `/reports/category-wise`

Upload statistics grouped by category.

#### Request

```http
GET /api/v1/reports/category-wise?fromDate=2026-01-01&toDate=2026-06-25
Authorization: Bearer <token>
```

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "CategoryId": 2,
        "CategoryName": "GST Documents",
        "DocumentCount": 22,
        "TotalSize": 23068672
      }
    ]
  },
  "jsonstring": ""
}
```

---

### GET `/reports/audit-logs`

System audit trail with optional filters.

#### Request

```http
GET /api/v1/reports/audit-logs?fromDate=2026-06-01&toDate=2026-06-25&userId=42
Authorization: Bearer <token>
```

| Query param | Description |
|-------------|-------------|
| `fromDate` | Start date (optional) |
| `toDate` | End date (optional) |
| `userId` | Filter by user (optional) |

#### Success response

```json
{
  "status": true,
  "statuscode": "0",
  "message": "Success",
  "data": {
    "Array0": [
      {
        "AuditLogId": 501,
        "UserId": 42,
        "Action": "Login",
        "EntityName": "Users",
        "EntityId": "42",
        "OldValues": null,
        "NewValues": null,
        "IpAddress": "192.168.1.10",
        "CreatedDate": "2026-06-25T09:00:00",
        "UserName": "Rajesh Kumar"
      }
    ]
  },
  "jsonstring": ""
}
```

---

## Error Handling

### Application-level errors

Failed business logic returns HTTP `200` with `status: false` and an appropriate `statuscode`. Always check `status` before reading `data`.

### HTTP-level errors

| HTTP status | Cause |
|-------------|-------|
| `400` | Model validation failure (malformed JSON, missing required fields) |
| `401` | Missing/expired JWT (no valid `Authorization` header) |
| `403` | Authenticated but insufficient role |
| `429` | Rate limit exceeded (100 requests/minute per user/host) |
| `500` | Unhandled exception (generic message returned) |

#### Validation error (HTTP 400)

```json
{
  "status": false,
  "statuscode": "1001",
  "message": "Validation failed.",
  "data": null,
  "jsonstring": "The Password field is required."
}
```

#### Internal error

```json
{
  "status": false,
  "statuscode": "500",
  "message": "An error occurred while processing your request.",
  "data": null,
  "jsonstring": ""
}
```

---

## Rate Limiting

A global rate limiter allows **100 requests per minute** per authenticated user (or per host for anonymous requests). Exceeding the limit returns HTTP `429 Too Many Requests`.

---

## Quick Reference — All Endpoints

| Method | Endpoint | Auth | Role |
|--------|----------|------|------|
| POST | `/auth/register` | — | — |
| POST | `/auth/login` | — | — |
| POST | `/auth/refresh` | — | — |
| POST | `/auth/change-password` | Bearer | Any |
| POST | `/auth/forgot-password` | — | — |
| POST | `/auth/verify-otp` | — | — |
| POST | `/auth/reset-password` | — | — |
| GET | `/users` | Bearer | SuperAdmin |
| GET | `/users/{id}` | Bearer | SuperAdmin / own |
| GET | `/users/profile` | Bearer | Any |
| PUT | `/users/profile` | Bearer | Any |
| POST | `/users/{id}/approval` | Bearer | SuperAdmin |
| POST | `/users/{id}/status` | Bearer | SuperAdmin |
| GET | `/categories` | Bearer | Any |
| POST | `/categories` | Bearer | SuperAdmin |
| PUT | `/categories/{id}` | Bearer | SuperAdmin |
| DELETE | `/categories/{id}` | Bearer | SuperAdmin |
| POST | `/documents/upload` | Bearer | Any |
| GET | `/documents/history` | Bearer | Any (Client scoped) |
| GET | `/documents/dashboard` | Bearer | Client |
| GET | `/documents/{id}/download` | Bearer | Any |
| GET | `/reports/daily` | Bearer | SuperAdmin |
| GET | `/reports/monthly` | Bearer | SuperAdmin |
| GET | `/reports/user-wise` | Bearer | SuperAdmin |
| GET | `/reports/category-wise` | Bearer | SuperAdmin |
| GET | `/reports/audit-logs` | Bearer | SuperAdmin |

---

## Frontend Client Configuration

The Flutter `dms_client` app configures the API base URL in `lib/core/config/app_config.dart`:

| Platform | Base URL |
|----------|----------|
| Web / Desktop / iOS | `http://localhost:5000` |
| Android emulator | `http://10.0.2.2:5000` |

Full API URL: `{baseUrl}/api/v1` + endpoint path (e.g. `/auth/login`).

Repository layer files for cross-reference:

- `lib/data/repositories/auth_repository.dart`
- `lib/data/repositories/user_repository.dart`
- `lib/data/repositories/category_repository.dart`
- `lib/data/repositories/document_repository.dart`
- `lib/data/models/api_response.dart` (response parsing)
