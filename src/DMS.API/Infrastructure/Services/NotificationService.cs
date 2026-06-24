using DMS.Application.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace DMS.Infrastructure.Services;

public class NotificationService : INotificationService
{
    private readonly ILogger<NotificationService> _logger;
    private readonly IConfiguration _configuration;
    private readonly SmtpEmailSender _emailSender;

    public NotificationService(
        ILogger<NotificationService> logger,
        IConfiguration configuration,
        SmtpEmailSender emailSender)
    {
        _logger = logger;
        _configuration = configuration;
        _emailSender = emailSender;
    }

    public async Task SendApprovalCredentialsAsync(string name, string email, string username, string password)
    {
        var subject = "Your ProfitSheild account has been approved";
        var body = EmailTemplates.ApprovalCredentials(name, username, password);
        await SendEmailSafe(email, subject, body, "approval credentials");
    }

    public async Task SendForgotPasswordOtpAsync(string name, string email, string otp, int expiryMinutes)
    {
        var subject = "ProfitSheild password reset OTP";
        var body = EmailTemplates.ForgotPasswordOtp(name, otp, expiryMinutes);
        await SendEmailSafe(email, subject, body, "password reset OTP");
    }

    public async Task SendPasswordResetConfirmationAsync(string name, string email, string username, string newPassword)
    {
        var subject = "Your ProfitSheild password has been updated";
        var body = EmailTemplates.PasswordResetConfirmation(name, username, newPassword);
        await SendEmailSafe(email, subject, body, "password reset confirmation");
    }

    public async Task SendRegistrationAcknowledgementAsync(string email, string name)
    {
        var subject = "ProfitSheild registration received";
        var body = EmailTemplates.RegistrationAcknowledgement(name);
        await SendEmailSafe(email, subject, body, "registration acknowledgement");
    }

    private async Task SendEmailSafe(string email, string subject, string body, string context)
    {
        try
        {
            await _emailSender.SendAsync(email, subject, body);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send {Context} email to {Email}", context, email);
        }
    }
}
