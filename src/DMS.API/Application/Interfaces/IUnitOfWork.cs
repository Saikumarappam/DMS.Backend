namespace DMS.Application.Interfaces;

/// <summary>
/// Unit of Work facade over repositories. Stored procedures commit per call;
/// this type coordinates shared repository access across application services.
/// </summary>
public interface IUnitOfWork
{
    IUserRepository Users { get; }
    ICategoryRepository Categories { get; }
    IDocumentRepository Documents { get; }
    IRefreshTokenRepository RefreshTokens { get; }
    IPasswordResetRepository PasswordResets { get; }
    IReportRepository Reports { get; }
    IAuditRepository Audit { get; }
}
