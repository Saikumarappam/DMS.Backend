# DMS Backend

Single-project ASP.NET Core API for the DMS Flutter client.

## Requirements

- [.NET 10 SDK](https://dotnet.microsoft.com/download) (see `global.json`)

## Project structure

```
src/DMS.API/
├── Controllers/          # HTTP endpoints
├── Middleware/           # Exception handling, request logging
├── Application/          # Services, DTOs, interfaces
├── Domain/               # Entity models
├── Infrastructure/       # SQL repositories, JWT, file storage
├── Helpers/              # SqlHelper (stored procedure access)
├── Program.cs
└── appsettings.json
```

## Run

```powershell
dotnet run --project src/DMS.API/DMS.API.csproj
```

Swagger UI: `https://localhost:5001/swagger`

## Database scripts (run in order)

1. `database/01_Schema.sql`
2. `database/02_StoredProcedures.sql`
3. `database/03_SeedData.sql`
4. `database/05_ApisAlignedSpAndTables.sql` — ApiRequestLogs, sp_ApiRequestLog_Insert, lookup SPs

## API response contract

All endpoints return a typed envelope:

```json
{
  "success": true,
  "message": "Success",
  "resultCode": 0,
  "data": { },
  "errors": []
}
```

### Result codes

| Code | Meaning |
|------|---------|
| `0` | Success (matches stored procedure success) |
| `1001` | Validation failed |
| `1002` | Resource not found |
| `1003` | Invalid credentials |
| `1004` | Invalid/expired token |
| `1005` | Account not approved |
| `1006` | Account locked |
| `1999` | Unexpected server error |
| Negative values | Stored procedure business errors (e.g. duplicate email) |

HTTP status codes are mapped from `resultCode` in controllers (400, 401, 403, 404, 500).

All database access uses stored procedures only — no inline SQL in application code.
