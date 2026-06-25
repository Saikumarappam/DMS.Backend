using System.Data;
using DMS.Domain.Entities;

namespace DMS.Application.Interfaces;

public interface IUserRepository
{
    Task<DataSet> GetAllDataSetAsync(string? status, string? search);
    Task<DataSet> GetByIdDataSetAsync(long userId);
    Task<DataSet> GetByUsernameDataSetAsync(string username);
    Task<DataSet> GetByPanDataSetAsync(string panNumber);
    Task<DataSet> GetByEmailDataSetAsync(string email);
    Task<DataSet> LoginDataSetAsync(string username, bool isPasswordValid, int maxAttempts = 5, int lockoutMinutes = 30);

    Task<DataSet> RegisterDataSetAsync(
        string name, string mobile, string email, string pan, string? address,
        string? businessName, string? contactPerson, string? gst,
        string passwordHash, string originalPassword);

    Task<DataSet> ApproveRejectDataSetAsync(
        long userId, string action, string? comments, long actionBy);

    Task<DataSet> ActivateDeactivateDataSetAsync(long userId, bool isActive, long actionBy);

    Task<DataSet> UpdateProfileDataSetAsync(
        long userId, string name, string mobile, string email, string? address,
        string? businessName, string? contactPerson, string? gst, bool profileCompleted, long modifiedBy);

    Task<DataSet> ChangePasswordDataSetAsync(long userId, string newHash, string originalPassword, long modifiedBy);

    Task<User?> GetByUsernameAsync(string username);
    Task<(User? User, string? NotFoundMessage)> GetByUsernameOrMessageAsync(string username);
    Task<User?> GetByPanAsync(string panNumber);
    Task<User?> GetByIdAsync(long userId);
    Task<User?> GetByEmailAsync(string email);
}

public interface ICategoryRepository
{
    Task<DataSet> GetAllDataSetAsync(bool includeInactive = false);
    Task<List<FileCategory>> GetAllAsync(bool includeInactive = false);
    Task<DataSet> AddDataSetAsync(string name, string? description, long createdBy);
    Task<DataSet> UpdateDataSetAsync(int id, string name, string? description, long modifiedBy);
    Task<DataSet> DeleteDataSetAsync(int id, long modifiedBy);
}

public interface IDocumentRepository
{
    Task<DataSet> GetHistoryDataSetAsync(long? clientId, int? categoryId, DateTime? from, DateTime? to, string? search);
    Task<DataSet> GetByIdDataSetAsync(long fileId);
    Task<DataSet> GetDashboardStatsDataSetAsync(long clientId);

    Task<DataSet> UploadDataSetAsync(
        long clientId, int categoryId, string categoryName, string fileName, string originalName,
        string filePath, string extension, long fileSize, string source, long createdBy, string? fileBase64 = null);

    Task<FileDetail?> GetByIdAsync(long fileId);
}

public interface IRefreshTokenRepository
{
    Task SaveAsync(long userId, string token, DateTime expiresAt, string? ip);
    Task<(long UserId, string Username)?> GetValidTokenAsync(string token);
    Task RevokeAsync(string token, string? replacedBy = null);
}

public interface IReportRepository
{
    Task<DataSet> GetDailyUploadsDataSetAsync(DateTime from, DateTime to);
    Task<DataSet> GetMonthlyUploadsDataSetAsync(int year);
    Task<DataSet> GetUserWiseDataSetAsync(DateTime? from, DateTime? to);
    Task<DataSet> GetCategoryWiseDataSetAsync(DateTime? from, DateTime? to);

    Task<List<ReportItem>> GetDailyUploadsAsync(DateTime from, DateTime to);
    Task<List<ReportItem>> GetMonthlyUploadsAsync(int year);
    Task<List<ReportItem>> GetUserWiseAsync(DateTime? from, DateTime? to);
    Task<List<ReportItem>> GetCategoryWiseAsync(DateTime? from, DateTime? to);
}

public interface IAuditRepository
{
    Task<DataSet> GetLogsDataSetAsync(DateTime? from, DateTime? to, long? userId);
    Task<List<AuditLog>> GetLogsAsync(DateTime? from, DateTime? to, long? userId);
    Task LogAsync(long? userId, string action, string entity, string? entityId, string? newValues, string? ip);
}

public interface IPasswordResetRepository
{
    Task SaveOtpAsync(long userId, string otpHash, DateTime expiresAt);
    Task<PasswordOtpRecord?> GetActiveOtpAsync(long userId);
    Task IncrementOtpAttemptAsync(long otpId);
    Task SetOtpVerifiedAsync(long otpId, string resetSessionToken, DateTime sessionExpiresAt);
    Task<PasswordOtpSessionRecord?> GetVerifiedSessionAsync(string email, string resetSessionToken);
    Task MarkOtpUsedAsync(long otpId);
}

public record PasswordOtpRecord(
    long OtpId,
    long UserId,
    string OtpHash,
    DateTime ExpiresAt,
    int AttemptCount,
    bool IsVerified,
    bool IsUsed,
    string? ResetSessionToken,
    DateTime? SessionExpiresAt);

public record PasswordOtpSessionRecord(
    long OtpId,
    long UserId,
    string Email,
    string? Username,
    DateTime SessionExpiresAt);

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string hash);
}

public interface ITokenService
{
    string GenerateAccessToken(User user);
    string GenerateRefreshToken();
    DateTime GetAccessTokenExpiry();
}

public interface IFileStorageService
{
    Task<(string storedName, string filePath)> SaveFileAsync(byte[] content, string originalName, long clientId);
    Task<(Stream stream, string contentType)?> TryGetFileAsync(string filePath);
    string GetContentType(string extension);
    bool IsAllowedExtension(string extension);
    bool IsAllowedSize(long size);
}
