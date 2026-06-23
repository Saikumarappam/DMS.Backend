namespace DMS.Application.DTOs.Auth;

public class RegisterRequest
{
    public string Name { get; set; } = string.Empty;
    public string MobileNumber { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PANNumber { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? BusinessName { get; set; }
    public string? ContactPersonName { get; set; }
    public string? GSTNumber { get; set; }
}

public class LoginRequest
{
    /// <summary>User PAN number (e.g. ABCDE1234F).</summary>
    public string Username { get; set; } = string.Empty;
    /// <summary>Plain-text password from login/change-password request (never a BCrypt hash).</summary>
    public string Password { get; set; } = string.Empty;
}

public class RefreshTokenRequest
{
    public string RefreshToken { get; set; } = string.Empty;
}

public class ChangePasswordRequest
{
    public string CurrentPassword { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}

public class ForgotPasswordRequest
{
    public string Email { get; set; } = string.Empty;
}

public class VerifyOtpRequest
{
    public string Email { get; set; } = string.Empty;
    public string Otp { get; set; } = string.Empty;
}

public class ResetPasswordRequest
{
    public string Email { get; set; } = string.Empty;
    public string ResetToken { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
    public string ConfirmPassword { get; set; } = string.Empty;
}

public class AuthResponse
{
    public string AccessToken { get; set; } = string.Empty;
    public string RefreshToken { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public UserDto User { get; set; } = new();
}

public class UserDto
{
    public long UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string MobileNumber { get; set; } = string.Empty;
    public string? BusinessName { get; set; }
    public string RoleName { get; set; } = string.Empty;
    public string UserStatus { get; set; } = string.Empty;
    public bool ProfileCompleted { get; set; }
}
