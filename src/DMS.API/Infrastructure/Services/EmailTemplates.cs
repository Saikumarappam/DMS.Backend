using System.Net;

namespace DMS.Infrastructure.Services;

public static class EmailTemplates
{
    public static string RegistrationAcknowledgement(string name) => Wrap(
        "Registration Received",
        $"""
        <p>Dear {Encode(name)},</p>
        <p>Thank you for registering with the Document Management System.</p>
        <p>Your application is under review. Once approved, sign in using your PAN number as the username and the password you chose during registration.</p>
        <p>Regards,<br/>DMS Team</p>
        """);

    public static string ApprovalNotification(string name, string username) => Wrap(
        "Your DMS Account Has Been Approved",
        $"""
        <p>Dear {Encode(name)},</p>
        <p>Your account has been approved. You can now sign in with:</p>
        <table style="border-collapse:collapse;margin:16px 0;">
          <tr><td style="padding:8px 12px;background:#f4f4f4;font-weight:bold;">Username</td><td style="padding:8px 12px;">{Encode(username)}</td></tr>
          <tr><td style="padding:8px 12px;background:#f4f4f4;font-weight:bold;">Password</td><td style="padding:8px 12px;">Use the password you set during registration</td></tr>
        </table>
        <p>Regards,<br/>DMS Team</p>
        """);

    public static string ApprovalCredentials(string name, string username, string password) => Wrap(
        "Your DMS Account Has Been Approved",
        $"""
        <p>Dear {Encode(name)},</p>
        <p>Your account has been approved. Please use the credentials below to sign in:</p>
        <table style="border-collapse:collapse;margin:16px 0;">
          <tr><td style="padding:8px 12px;background:#f4f4f4;font-weight:bold;">Username</td><td style="padding:8px 12px;">{Encode(username)}</td></tr>
          <tr><td style="padding:8px 12px;background:#f4f4f4;font-weight:bold;">Password</td><td style="padding:8px 12px;">{Encode(password)}</td></tr>
        </table>
        <p>For security, change your password after your first login.</p>
        <p>Regards,<br/>DMS Team</p>
        """);

    public static string ForgotPasswordOtp(string name, string otp, int expiryMinutes) => Wrap(
        "Password Reset OTP",
        $"""
        <p>Dear {Encode(name)},</p>
        <p>We received a request to reset your password. Use the OTP below:</p>
        <p style="font-size:28px;font-weight:bold;letter-spacing:6px;color:#1a5fb4;">{Encode(otp)}</p>
        <p>This OTP is valid for <strong>{expiryMinutes} minutes</strong>. Do not share it with anyone.</p>
        <p>If you did not request this, you can ignore this email.</p>
        <p>Regards,<br/>DMS Team</p>
        """);

    public static string PasswordResetConfirmation(string name, string username, string newPassword) => Wrap(
        "Password Updated Successfully",
        $"""
        <p>Dear {Encode(name)},</p>
        <p>Your password has been updated successfully.</p>
        <table style="border-collapse:collapse;margin:16px 0;">
          <tr><td style="padding:8px 12px;background:#f4f4f4;font-weight:bold;">Username</td><td style="padding:8px 12px;">{Encode(username)}</td></tr>
          <tr><td style="padding:8px 12px;background:#f4f4f4;font-weight:bold;">New Password</td><td style="padding:8px 12px;">{Encode(newPassword)}</td></tr>
        </table>
        <p><strong>Please sign in again using your new password.</strong></p>
        <p>Regards,<br/>DMS Team</p>
        """);

    private static string Wrap(string title, string body) =>
        $"""
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"/><title>{Encode(title)}</title></head>
        <body style="font-family:Segoe UI,Arial,sans-serif;color:#222;line-height:1.5;max-width:600px;margin:0 auto;padding:24px;">
          <div style="border-bottom:3px solid #1a5fb4;padding-bottom:12px;margin-bottom:20px;">
            <h2 style="margin:0;color:#1a5fb4;">Document Management System</h2>
          </div>
          {body}
          <hr style="margin-top:32px;border:none;border-top:1px solid #ddd;"/>
          <p style="font-size:12px;color:#666;">This is an automated message. Please do not reply.</p>
        </body>
        </html>
        """;

    private static string Encode(string value) => WebUtility.HtmlEncode(value);
}
