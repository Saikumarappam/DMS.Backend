using Asp.Versioning;
using DMS.Application.DTOs.Auth;
using DMS.Application.DTOs.Common;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/auth")]
public class AuthController : ApiControllerBase
{
    private readonly AuthService _authService;

    public AuthController(AuthService authService) => _authService = authService;

    [HttpPost("register")]
    [AllowAnonymous]
    public Task<Response> Register([FromBody] RegisterRequest request) =>
        _authService.RegisterAsync(request);

    [HttpPost("login")]
    [AllowAnonymous]
    public Task<Response> Login([FromBody] LoginRequest request) =>
        _authService.LoginAsync(request, ClientIp);

    [HttpPost("refresh")]
    [AllowAnonymous]
    public Task<Response> Refresh([FromBody] RefreshTokenRequest request) =>
        _authService.RefreshTokenAsync(request, ClientIp);

    [HttpPost("change-password")]
    [Authorize]
    public Task<Response> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _authService.ChangePasswordAsync(userId, request);
    }

    [HttpPost("forgot-password")]
    [AllowAnonymous]
    public Task<Response> ForgotPassword([FromBody] ForgotPasswordRequest request) =>
        _authService.ForgotPasswordAsync(request);

    [HttpPost("verify-otp")]
    [AllowAnonymous]
    public Task<Response> VerifyOtp([FromBody] VerifyOtpRequest request) =>
        _authService.VerifyOtpAsync(request);

    [HttpPost("reset-password")]
    [AllowAnonymous]
    public Task<Response> ResetPassword([FromBody] ResetPasswordRequest request) =>
        _authService.ResetPasswordAsync(request);
}
