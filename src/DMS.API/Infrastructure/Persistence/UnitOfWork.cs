using DMS.Application.Interfaces;
using DMS.Infrastructure.Repositories;

namespace DMS.Infrastructure.Persistence;

public class UnitOfWork : IUnitOfWork
{
    public UnitOfWork(
        IUserRepository users,
        ICategoryRepository categories,
        IDocumentRepository documents,
        IRefreshTokenRepository refreshTokens,
        IPasswordResetRepository passwordResets,
        IReportRepository reports,
        IAuditRepository audit)
    {
        Users = users;
        Categories = categories;
        Documents = documents;
        RefreshTokens = refreshTokens;
        PasswordResets = passwordResets;
        Reports = reports;
        Audit = audit;
    }

    public IUserRepository Users { get; }
    public ICategoryRepository Categories { get; }
    public IDocumentRepository Documents { get; }
    public IRefreshTokenRepository RefreshTokens { get; }
    public IPasswordResetRepository PasswordResets { get; }
    public IReportRepository Reports { get; }
    public IAuditRepository Audit { get; }
}
