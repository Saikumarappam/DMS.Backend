using System.Text.RegularExpressions;

namespace DMS.Application.Common;

public static class ValidationRules
{
    private static readonly Regex PanRegex = new(@"^[A-Z]{5}[0-9]{4}[A-Z]{1}$", RegexOptions.Compiled);

    public static bool IsValidEmail(string? email) =>
        !string.IsNullOrWhiteSpace(email) &&
        Regex.IsMatch(email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$");

    public static bool IsValidPanNumber(string? pan) =>
        !string.IsNullOrWhiteSpace(pan) && PanRegex.IsMatch(pan.Trim().ToUpperInvariant());

    public static string NormalizePanNumber(string pan) => pan.Trim().ToUpperInvariant();

    /// <summary>Admin keeps literal username; clients use PAN format.</summary>
    public static string NormalizeLoginUsername(string? username)
    {
        if (string.IsNullOrWhiteSpace(username))
            return string.Empty;

        var trimmed = username.Trim();
        if (string.Equals(trimmed, "admin", StringComparison.OrdinalIgnoreCase))
            return "admin";

        return NormalizePanNumber(trimmed);
    }

    public static bool IsValidLoginUsername(string username)
    {
        if (string.Equals(username, "admin", StringComparison.OrdinalIgnoreCase))
            return true;

        return IsValidPanNumber(username);
    }

    public static bool IsValidOtp(string? otp, int length = 6) =>
        !string.IsNullOrWhiteSpace(otp) &&
        otp.Length == length &&
        Regex.IsMatch(otp, @"^\d+$");

    public static bool IsStrongPassword(string password) =>
        password.Length >= 8 &&
        Regex.IsMatch(password, @"[A-Z]") &&
        Regex.IsMatch(password, @"[a-z]") &&
        Regex.IsMatch(password, @"[0-9]") &&
        Regex.IsMatch(password, @"[^a-zA-Z0-9]");

    public static List<string> ValidateApproval(string action)
    {
        var errors = new List<string>();
        if (action != "Approve" && action != "Reject")
            errors.Add("Action must be Approve or Reject.");

        return errors;
    }
}
