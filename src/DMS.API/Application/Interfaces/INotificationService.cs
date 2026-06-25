namespace DMS.Application.Interfaces;

public interface INotificationService
{
    Task SendApprovalNotificationAsync(string name, string email, string username,string OriginalPassword);
    Task SendForgotPasswordOtpAsync(string name, string email, string otp, int expiryMinutes);
    Task SendPasswordResetConfirmationAsync(string name, string email, string username, string newPassword);
    Task SendRegistrationAcknowledgementAsync(string email, string name);
}
