using Asp.Versioning;
using DMS.Application.DTOs.Auth;
using DMS.Application.DTOs.Common;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

/// <summary>Authentication and password management.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/auth")]
[Tags("Auth")]
[Produces("application/json")]
public class AuthController : ApiControllerBase
{
    private readonly AuthService _authService;

    public AuthController(AuthService authService) => _authService = authService;

    /// <summary>Register a new client (status: Pending until admin approval).</summary>
    /// <remarks>Frontend: <c>RegisterScreen</c> (<c>/register</c>)</remarks>
    [HttpPost("register")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    public Task<Response> Register([FromBody] RegisterRequest request) =>
        _authService.RegisterAsync(request);

    /// <summary>Sign in with PAN (client) or admin username.</summary>
    /// <remarks>Frontend: <c>LoginScreen</c> (<c>/login</c>). Returns <see cref="TokenResponse"/> with JWT and user profile in data.Array0.</remarks>
    [HttpPost("login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(TokenResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    public Task<Response> Login([FromBody] LoginRequest request) =>
        _authService.LoginAsync(request, ClientIp);

    /// <summary>Refresh an expired access token.</summary>
    /// <remarks>Frontend: <c>AuthInterceptor</c> (auto on 401), session restore. Returns <see cref="TokenResponse"/>.</remarks>
    [HttpPost("refresh")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(TokenResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    public Task<Response> Refresh([FromBody] RefreshTokenRequest request) =>
        _authService.RefreshTokenAsync(request, ClientIp);

    /// <summary>Change password for the authenticated user.</summary>
    /// <remarks>Frontend: <c>ChangePasswordScreen</c> (<c>/change-password</c>)</remarks>
    [HttpPost("change-password")]
    [Authorize]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public Task<Response> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _authService.ChangePasswordAsync(userId, request);
    }

    /// <summary>Request a password-reset OTP by email.</summary>
    /// <remarks>Frontend: <c>PasswordRecoveryScreen</c> step 1 (<c>/forgot-password</c>)</remarks>
    [HttpPost("forgot-password")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    public Task<Response> ForgotPassword([FromBody] ForgotPasswordRequest request) =>
        _authService.ForgotPasswordAsync(request);

    /// <summary>Verify OTP and receive a reset token (jsonstring).</summary>
    /// <remarks>Frontend: <c>PasswordRecoveryScreen</c> step 2</remarks>
    [HttpPost("verify-otp")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    public Task<Response> VerifyOtp([FromBody] VerifyOtpRequest request) =>
        _authService.VerifyOtpAsync(request);

    /// <summary>Set a new password using the reset token from verify-otp.</summary>
    /// <remarks>Frontend: <c>PasswordRecoveryScreen</c> step 3</remarks>
    [HttpPost("reset-password")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    public Task<Response> ResetPassword([FromBody] ResetPasswordRequest request) =>
        _authService.ResetPasswordAsync(request);
}
