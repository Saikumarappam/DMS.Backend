using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using MimeKit;

namespace DMS.Infrastructure.Services;

public class SmtpEmailSender
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<SmtpEmailSender> _logger;

    public SmtpEmailSender(IConfiguration configuration, ILogger<SmtpEmailSender> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendAsync(string toEmail, string subject, string htmlBody)
    {
        if (!_configuration.GetValue("Notifications:EmailEnabled", false))
        {
            _logger.LogWarning("Email disabled. Would send '{Subject}' to {Email}", subject, toEmail);
            return;
        }

        var host = _configuration["Notifications:SmtpHost"];
        if (string.IsNullOrWhiteSpace(host))
        {
            _logger.LogWarning("SMTP host not configured. Email '{Subject}' to {Email} was not sent.", subject, toEmail);
            return;
        }

        var port = _configuration.GetValue("Notifications:SmtpPort", 587);
        var fromEmail = _configuration["Notifications:FromEmail"] ?? "noreply@dms.local";
        var fromName = _configuration["Notifications:FromName"] ?? "DMS";
        var smtpUser = _configuration["Notifications:SmtpUser"];
        var smtpPassword = _configuration["Notifications:SmtpPassword"];
        var enableSsl = _configuration.GetValue("Notifications:SmtpEnableSsl", true);

        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(fromName, fromEmail));
        message.To.Add(MailboxAddress.Parse(toEmail));
        message.Subject = subject;
        message.Body = new TextPart("html") { Text = htmlBody };

        using var client = new SmtpClient();
        await client.ConnectAsync(host, port, enableSsl ? SecureSocketOptions.StartTls : SecureSocketOptions.Auto);
        if (!string.IsNullOrWhiteSpace(smtpUser))
            await client.AuthenticateAsync(smtpUser, smtpPassword);

        await client.SendAsync(message);
        await client.DisconnectAsync(true);

        _logger.LogInformation("Email sent to {Email}: {Subject}", toEmail, subject);
    }
}
