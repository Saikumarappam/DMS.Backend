namespace DMS.Application.DTOs.Common;

public static class ResponseHelper
{
    public const string ValidationError = "1001";
    public const string NotFound = "1002";
    public const string InvalidCredentials = "1003";
    public const string TokenError = "1004";
    public const string AccountLocked = "1005";
    public const string Forbidden = "403";
    public const string Unauthorized = "401";
    public const string InternalError = "500";

    public static Response Success(string message = "Success") =>
        new() { status = true, statuscode = "0", message = message };

    public static Response SuccessWithJson(string message, string jsonstring)
    {
        var resp = Success(message);
        resp.jsonstring = jsonstring;
        return resp;
    }

    public static Response Validation(string message) =>
        new() { status = false, statuscode = ValidationError, message = message };

    public static Response Validation(IEnumerable<string> errors) =>
        Validation(string.Join("; ", errors));

    public static Response NotFoundResponse(string message = "Resource not found.") =>
        new() { status = false, statuscode = NotFound, message = message };

    public static Response InvalidCredentialsResponse(string message = "Invalid username or password.") =>
        new() { status = false, statuscode = InvalidCredentials, message = message };

    public static Response TokenErrorResponse(string message = "Invalid or expired token.") =>
        new() { status = false, statuscode = TokenError, message = message };

    public static Response AccountLockedResponse(string message = "Account is not approved or is locked.") =>
        new() { status = false, statuscode = AccountLocked, message = message };

    public static Response ForbiddenResponse(string message = "Access denied.") =>
        new() { status = false, statuscode = Forbidden, message = message };

    public static Response UnauthorizedResponse(string message = "Invalid or missing user identity.") =>
        new() { status = false, statuscode = Unauthorized, message = message };

    public static Response InternalErrorResponse(string message = "An error occurred while processing your request.") =>
        new() { status = false, statuscode = InternalError, message = message };

    public static string MapStatusCode(int resultCode, string message)
    {
        if (resultCode == 0)
            return "0";

        var text = message ?? string.Empty;

        if (text.Contains("not found", StringComparison.OrdinalIgnoreCase))
            return NotFound;

        if (text.Contains("locked", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("not approved", StringComparison.OrdinalIgnoreCase))
            return AccountLocked;

        if (text.Contains("password", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("username", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("credentials", StringComparison.OrdinalIgnoreCase))
            return InvalidCredentials;

        if (text.Contains("already registered", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("already exists", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("already in use", StringComparison.OrdinalIgnoreCase) ||
            text.Contains("invalid", StringComparison.OrdinalIgnoreCase))
            return ValidationError;

        return resultCode.ToString();
    }
}
