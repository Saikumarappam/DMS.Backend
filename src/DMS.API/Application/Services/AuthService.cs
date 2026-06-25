using System.Text.RegularExpressions;
using DMS.API.Helpers;
using DMS.Application.Common;
using DMS.Application.DTOs.Auth;
using DMS.Application.DTOs.Common;
using DMS.Application.Interfaces;
using DMS.Domain.Entities;
using DMS.Infrastructure.Repositories;
using Microsoft.Extensions.Configuration;

namespace DMS.Application.Services;

public class AuthService
{
    private readonly IUserRepository _userRepo;
    private readonly IRefreshTokenRepository _refreshTokenRepo;
    private readonly IPasswordResetRepository _passwordResetRepo;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ITokenService _tokenService;
    private readonly IAuditRepository _auditRepo;
    private readonly INotificationService _notificationService;
    private readonly CommonFunctions _commonFunctions;
    private readonly SpResponseBuilder _spResponse;
    private readonly IConfiguration _configuration;

    public AuthService(
        IUserRepository userRepo,
        IRefreshTokenRepository refreshTokenRepo,
        IPasswordResetRepository passwordResetRepo,
        IPasswordHasher passwordHasher,
        ITokenService tokenService,
        IAuditRepository auditRepo,
        INotificationService notificationService,
        CommonFunctions commonFunctions,
        SpResponseBuilder spResponse,
        IConfiguration configuration)
    {
        _userRepo = userRepo;
        _refreshTokenRepo = refreshTokenRepo;
        _passwordResetRepo = passwordResetRepo;
        _passwordHasher = passwordHasher;
        _tokenService = tokenService;
        _auditRepo = auditRepo;
        _notificationService = notificationService;
        _commonFunctions = commonFunctions;
        _spResponse = spResponse;
        _configuration = configuration;
    }

    public async Task<Response> RegisterAsync(RegisterRequest request)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(request.Email, request.MobileNumber);
        try
        {
            var errors = ValidateRegistration(request);
            if (errors.Count > 0)
            {
                var resp = ResponseHelper.Validation(errors);
                _commonFunctions.LogEvent("AuthService.cs", "RegisterAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            var passwordHash = _passwordHasher.Hash(request.Password);
            var ds = await _userRepo.RegisterDataSetAsync(
                request.Name, request.MobileNumber, request.Email, ValidationRules.NormalizePanNumber(request.PANNumber),
                request.Address, request.BusinessName, request.ContactPersonName, request.GSTNumber,
                passwordHash, request.Password);

            var success = await _spResponse.FromCommandDataSetAsync(ds,
                "Registration successful. You will be notified by email once an administrator approves your account.");

            if (!success.status)
            {
                _commonFunctions.LogEvent("AuthService.cs", "RegisterAsync", paramsJson, success.message, 1, request.Email);
                return success;
            }

            await _notificationService.SendRegistrationAcknowledgementAsync(request.Email, request.Name);
            _commonFunctions.LogEvent("AuthService.cs", "RegisterAsync", paramsJson, success.message, 0, request.Email);
            return success;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("AuthService.cs", "RegisterAsync", paramsJson, ex.ToString(), 1, request.Email);
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> LoginAsync(LoginRequest request, string? ip)
    {
        var username = ValidationRules.NormalizeLoginUsername(request.Username);
        var paramsJson = await _commonFunctions.StringParamsToJson(username);
        try
        {
            if (!ValidationRules.IsValidLoginUsername(username))
            {
                var invalid = ResponseHelper.Validation("Invalid username. Use your PAN number or admin credentials.");
                _commonFunctions.LogEvent("AuthService.cs", "LoginAsync", paramsJson, invalid.message, 0, username);
                return invalid;
            }

            if (string.IsNullOrWhiteSpace(request.Password))
            {
                var missing = ResponseHelper.Validation("Password is required.");
                _commonFunctions.LogEvent("AuthService.cs", "LoginAsync", paramsJson, missing.message, 0, username);
                return missing;
            }

            var maxAttempts = _configuration.GetValue("Auth:MaxLoginAttempts", 5);
            var lockoutMinutes = _configuration.GetValue("Auth:LockoutMinutes", 30);

            var (user, _) = await ResolveUserForLoginAsync(username);
            if (user == null)
            {
                var notFoundDs = await _userRepo.LoginDataSetAsync(username, false, maxAttempts, lockoutMinutes);
                var notFoundResp = await _spResponse.FromCommandDataSetAsync(notFoundDs);
                _commonFunctions.LogEvent("AuthService.cs", "LoginAsync", paramsJson, notFoundResp.message, 0, username);
                return notFoundResp;
            }

            var (isPasswordValid, shouldRehash) = ValidatePassword(user, request.Password);
            var loginDs = await _userRepo.LoginDataSetAsync(username, isPasswordValid, maxAttempts, lockoutMinutes);
            var loginResp = await _spResponse.FromCommandDataSetAsync(loginDs);
            if (!loginResp.status)
            {
                _commonFunctions.LogEvent("AuthService.cs", "LoginAsync", paramsJson, loginResp.message, 0, username);
                return loginResp;
            }

            var loggedInUser = UserRepository.MapUserFromLoginDataSet(loginDs);
            if (loggedInUser == null)
            {
                var resp = ResponseHelper.InternalErrorResponse();
                _commonFunctions.LogEvent("AuthService.cs", "LoginAsync", paramsJson, "Login succeeded but user payload missing.", 1, username);
                return resp;
            }

            if (shouldRehash)
                await SyncPasswordHashAsync(loggedInUser.UserId, request.Password, loggedInUser.UserId);

            await _auditRepo.LogAsync(loggedInUser.UserId, "Login", "Users", loggedInUser.UserId.ToString(), null, ip);
            var authResp = await BuildAuthResponse(loggedInUser, ip, "Login successful.");
            _commonFunctions.LogEvent("AuthService.cs", "LoginAsync", paramsJson, authResp.message, 0, username);
            return authResp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("AuthService.cs", "LoginAsync", paramsJson, ex.ToString(), 1, username);
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> RefreshTokenAsync(RefreshTokenRequest request, string? ip)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(request.RefreshToken);
        try
        {
            if (string.IsNullOrWhiteSpace(request.RefreshToken))
            {
                var missing = ResponseHelper.TokenErrorResponse("Refresh token is required.");
                _commonFunctions.LogEvent("AuthService.cs", "RefreshTokenAsync", paramsJson, missing.message, 0, "");
                return missing;
            }

            var tokenData = await _refreshTokenRepo.GetValidTokenAsync(request.RefreshToken);
            if (tokenData == null)
            {
                var resp = ResponseHelper.TokenErrorResponse("Invalid or expired refresh token.");
                _commonFunctions.LogEvent("AuthService.cs", "RefreshTokenAsync", paramsJson, resp.message, 0, "");
                return resp;
            }

            var user = await _userRepo.GetByIdAsync(tokenData.Value.UserId);
            if (user == null)
            {
                var resp = ResponseHelper.NotFoundResponse("User not found.");
                _commonFunctions.LogEvent("AuthService.cs", "RefreshTokenAsync", paramsJson, resp.message, 0, tokenData.Value.UserId.ToString());
                return resp;
            }

            await _refreshTokenRepo.RevokeAsync(request.RefreshToken);
            var authResp = await BuildAuthResponse(user, ip, "Token refreshed successfully.");
            _commonFunctions.LogEvent("AuthService.cs", "RefreshTokenAsync", paramsJson, authResp.message, 0, user.UserId.ToString());
            return authResp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("AuthService.cs", "RefreshTokenAsync", paramsJson, ex.ToString(), 1, "");
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> ChangePasswordAsync(long userId, ChangePasswordRequest request)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(userId);
        try
        {
            if (!ValidationRules.IsStrongPassword(request.NewPassword))
            {
                var resp = ResponseHelper.Validation("Password does not meet strength requirements.");
                _commonFunctions.LogEvent("AuthService.cs", "ChangePasswordAsync", paramsJson, resp.message, 0, userId.ToString());
                return resp;
            }

            var user = await _userRepo.GetByIdAsync(userId);
            if (!ValidatePassword(user, request.CurrentPassword).isValid)
            {
                var resp = ResponseHelper.InvalidCredentialsResponse("Current password is incorrect.");
                _commonFunctions.LogEvent("AuthService.cs", "ChangePasswordAsync", paramsJson, resp.message, 0, userId.ToString());
                return resp;
            }

            var result = await SyncPasswordHashAsync(userId, request.NewPassword, userId);
            if (result.status)
                result.message = "Password changed successfully.";
            _commonFunctions.LogEvent("AuthService.cs", "ChangePasswordAsync", paramsJson, result.message, result.status ? 0 : 1, userId.ToString());
            return result;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("AuthService.cs", "ChangePasswordAsync", paramsJson, ex.ToString(), 1, userId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> ForgotPasswordAsync(ForgotPasswordRequest request)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(request.Email);
        try
        {
            if (!ValidationRules.IsValidEmail(request.Email))
            {
                var resp = ResponseHelper.Validation("Invalid email address.");
                _commonFunctions.LogEvent("AuthService.cs", "ForgotPasswordAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            var user = await _userRepo.GetByEmailAsync(request.Email);
            if (user != null)
            {
                if (user.UserStatus is not ("Approved" or "Active"))
                {
                    var resp = ResponseHelper.AccountLockedResponse("Account is not approved for login yet.");
                    _commonFunctions.LogEvent("AuthService.cs", "ForgotPasswordAsync", paramsJson, resp.message, 0, request.Email);
                    return resp;
                }

                var otpLength = _configuration.GetValue("Notifications:OtpLength", 6);
                var otp = GenerateOtp(otpLength);
                var otpHash = _passwordHasher.Hash(otp);
                var expiryMinutes = _configuration.GetValue("Notifications:OtpExpiryMinutes", 10);
                await _passwordResetRepo.SaveOtpAsync(user.UserId, otpHash, DateTime.UtcNow.AddMinutes(expiryMinutes));
                await _notificationService.SendForgotPasswordOtpAsync(user.Name, user.Email, otp, expiryMinutes);
            }

            var success = ResponseHelper.Success("If the email exists, an OTP has been sent to your registered email.");
            _commonFunctions.LogEvent("AuthService.cs", "ForgotPasswordAsync", paramsJson, success.message, 0, request.Email);
            return success;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("AuthService.cs", "ForgotPasswordAsync", paramsJson, ex.ToString(), 1, request.Email);
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> VerifyOtpAsync(VerifyOtpRequest request)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(request.Email);
        try
        {
            if (!ValidationRules.IsValidEmail(request.Email))
            {
                var resp = ResponseHelper.Validation("Invalid email address.");
                _commonFunctions.LogEvent("AuthService.cs", "VerifyOtpAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            var otpLength = _configuration.GetValue("Notifications:OtpLength", 6);
            if (!ValidationRules.IsValidOtp(request.Otp, otpLength))
            {
                var resp = ResponseHelper.Validation($"OTP must be a {otpLength}-digit number.");
                _commonFunctions.LogEvent("AuthService.cs", "VerifyOtpAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            var user = await _userRepo.GetByEmailAsync(request.Email);
            if (user == null)
            {
                var resp = ResponseHelper.TokenErrorResponse("Invalid OTP.");
                _commonFunctions.LogEvent("AuthService.cs", "VerifyOtpAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            var otpRecord = await _passwordResetRepo.GetActiveOtpAsync(user.UserId);
            if (otpRecord == null || otpRecord.IsUsed)
            {
                var resp = ResponseHelper.TokenErrorResponse("No active OTP found. Please request a new one.");
                _commonFunctions.LogEvent("AuthService.cs", "VerifyOtpAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            if (otpRecord.ExpiresAt < DateTime.UtcNow)
            {
                var resp = ResponseHelper.TokenErrorResponse("OTP has expired. Please request a new one.");
                _commonFunctions.LogEvent("AuthService.cs", "VerifyOtpAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            var maxAttempts = _configuration.GetValue("Notifications:OtpMaxAttempts", 5);
            if (otpRecord.AttemptCount >= maxAttempts)
            {
                var resp = ResponseHelper.TokenErrorResponse("Maximum OTP attempts exceeded. Please request a new OTP.");
                _commonFunctions.LogEvent("AuthService.cs", "VerifyOtpAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            if (!_passwordHasher.Verify(request.Otp, otpRecord.OtpHash))
            {
                await _passwordResetRepo.IncrementOtpAttemptAsync(otpRecord.OtpId);
                var remaining = maxAttempts - otpRecord.AttemptCount - 1;
                var resp = ResponseHelper.TokenErrorResponse(
                    remaining > 0
                        ? $"Invalid OTP. {remaining} attempt(s) remaining."
                        : "Invalid OTP. Maximum attempts exceeded. Please request a new OTP.");
                _commonFunctions.LogEvent("AuthService.cs", "VerifyOtpAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            var resetToken = Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32));
            var sessionMinutes = _configuration.GetValue("Notifications:ResetSessionExpiryMinutes", 15);
            await _passwordResetRepo.SetOtpVerifiedAsync(
                otpRecord.OtpId, resetToken, DateTime.UtcNow.AddMinutes(sessionMinutes));

            var success = ResponseHelper.SuccessWithJson("OTP verified. You may now set a new password.", resetToken);
            _commonFunctions.LogEvent("AuthService.cs", "VerifyOtpAsync", paramsJson, success.message, 0, user.UserId.ToString());
            return success;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("AuthService.cs", "VerifyOtpAsync", paramsJson, ex.ToString(), 1, request.Email);
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> ResetPasswordAsync(ResetPasswordRequest request)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(request.Email);
        try
        {
            if (!ValidationRules.IsValidEmail(request.Email))
            {
                var resp = ResponseHelper.Validation("Invalid email address.");
                _commonFunctions.LogEvent("AuthService.cs", "ResetPasswordAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            if (string.IsNullOrWhiteSpace(request.ResetToken))
            {
                var resp = ResponseHelper.Validation("Reset token is required. Verify OTP first.");
                _commonFunctions.LogEvent("AuthService.cs", "ResetPasswordAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            if (!ValidationRules.IsStrongPassword(request.NewPassword))
            {
                var resp = ResponseHelper.Validation("Password must be 8+ characters with upper, lower, digit, and special character.");
                _commonFunctions.LogEvent("AuthService.cs", "ResetPasswordAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            if (!string.Equals(request.NewPassword, request.ConfirmPassword, StringComparison.Ordinal))
            {
                var resp = ResponseHelper.Validation("New password and confirm password do not match.");
                _commonFunctions.LogEvent("AuthService.cs", "ResetPasswordAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            var session = await _passwordResetRepo.GetVerifiedSessionAsync(request.Email, request.ResetToken);
            if (session == null)
            {
                var resp = ResponseHelper.TokenErrorResponse("Invalid or expired reset session. Please verify OTP again.");
                _commonFunctions.LogEvent("AuthService.cs", "ResetPasswordAsync", paramsJson, resp.message, 0, request.Email);
                return resp;
            }

            var result = await SyncPasswordHashAsync(session.UserId, request.NewPassword, session.UserId, "Password reset successfully. Please sign in with your new password.");
            if (!result.status)
            {
                _commonFunctions.LogEvent("AuthService.cs", "ResetPasswordAsync", paramsJson, result.message, 1, session.UserId.ToString());
                return result;
            }

            await _passwordResetRepo.MarkOtpUsedAsync(session.OtpId);

            var user = await _userRepo.GetByIdAsync(session.UserId);
            if (user != null)
            {
                await _notificationService.SendPasswordResetConfirmationAsync(
                    user.Name,
                    user.Email,
                    user.Username ?? session.Username ?? request.Email,
                    request.NewPassword);
            }

            _commonFunctions.LogEvent("AuthService.cs", "ResetPasswordAsync", paramsJson, result.message, 0, session.UserId.ToString());
            return result;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("AuthService.cs", "ResetPasswordAsync", paramsJson, ex.ToString(), 1, request.Email);
            return ResponseHelper.InternalErrorResponse();
        }
    }

    private async Task<(User? User, string? LookupMessage)> ResolveUserForLoginAsync(string username)
    {
        var (user, notFoundMessage) = await _userRepo.GetByUsernameOrMessageAsync(username);
        if (user != null)
            return (user, null);

        if (ValidationRules.IsValidPanNumber(username))
        {
            var panUser = await _userRepo.GetByPanAsync(username);
            if (panUser != null)
                return (panUser, null);
        }

        return (null, notFoundMessage);
    }

    private (bool isValid, bool shouldRehash) ValidatePassword(User? user, string password)
    {
        if (user == null)
            return (false, false);

        if (!string.IsNullOrEmpty(user.PasswordHash) && _passwordHasher.Verify(password, user.PasswordHash))
            return (true, false);

        if (!string.IsNullOrEmpty(user.OriginalPassword) &&
            string.Equals(password, user.OriginalPassword, StringComparison.Ordinal))
            return (true, true);

        return (false, false);
    }

    private async Task<Response> SyncPasswordHashAsync(
        long userId, string plainPassword, long modifiedBy, string? successMessage = null)
    {
        var hash = _passwordHasher.Hash(plainPassword);
        var ds = await _userRepo.ChangePasswordDataSetAsync(userId, hash, plainPassword, modifiedBy);
        return await _spResponse.FromCommandDataSetAsync(ds, successMessage);
    }

    private static string GenerateOtp(int length)
    {
        var bytes = System.Security.Cryptography.RandomNumberGenerator.GetBytes(length);
        var chars = new char[length];
        for (var i = 0; i < length; i++)
            chars[i] = (char)('0' + bytes[i] % 10);
        return new string(chars);
    }

    private async Task<Response> BuildAuthResponse(User user, string? ip, string message = "Login successful.")
    {
        var accessToken = _tokenService.GenerateAccessToken(user);
        var refreshToken = _tokenService.GenerateRefreshToken();
        var expires = _tokenService.GetAccessTokenExpiry();
        await _refreshTokenRepo.SaveAsync(user.UserId, refreshToken, DateTime.UtcNow.AddDays(7), ip);

        var userDs = await _userRepo.GetByIdDataSetAsync(user.UserId);
        return await _spResponse.BuildAuthTokenResponseAsync(userDs, accessToken, refreshToken, expires, message);
    }

    public static List<string> ValidateRegistration(RegisterRequest r)
    {
        var errors = new List<string>();
        if (string.IsNullOrWhiteSpace(r.Name)) errors.Add("Name is required.");
        if (!Regex.IsMatch(r.MobileNumber, @"^[6-9]\d{9}$")) errors.Add("Invalid mobile number.");
        if (!Regex.IsMatch(r.Email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$")) errors.Add("Invalid email.");
        if (!ValidationRules.IsValidPanNumber(r.PANNumber)) errors.Add("Invalid PAN number.");
        if (string.IsNullOrWhiteSpace(r.Password)) errors.Add("Password is required.");
        else if (!ValidationRules.IsStrongPassword(r.Password)) errors.Add("Password must be at least 8 characters with uppercase, lowercase, number, and special character.");
        if (r.GSTNumber != null && !Regex.IsMatch(r.GSTNumber, @"^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$"))
            errors.Add("Invalid GST number.");
        return errors;
    }
}
