using DMS.API.Helpers;
using DMS.Application.Interfaces;
using DMS.Application.Services;
using DMS.Infrastructure.Repositories;
using DMS.Infrastructure.Services;
using Microsoft.Extensions.DependencyInjection;

namespace DMS.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services)
    {
        services.AddScoped<CommonFunctions>();
        services.AddScoped<SpResponseBuilder>();

        services.AddScoped<SmtpEmailSender>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<ICategoryRepository, CategoryRepository>();
        services.AddScoped<IDocumentRepository, DocumentRepository>();
        services.AddScoped<IRefreshTokenRepository, RefreshTokenRepository>();
        services.AddScoped<IPasswordResetRepository, PasswordResetRepository>();
        services.AddScoped<IReportRepository, ReportRepository>();
        services.AddScoped<IAuditRepository, AuditRepository>();
        services.AddScoped<ApiLogRepository>();
        services.AddScoped<IApiLogService, ApiLogService>();
        services.AddScoped<IUnitOfWork, Persistence.UnitOfWork>();
        services.AddScoped<IPasswordHasher, BcryptPasswordHasher>();
        services.AddScoped<ITokenService, JwtTokenService>();
        services.AddScoped<IFileStorageService, LocalFileStorageService>();
        services.AddScoped<INotificationService, NotificationService>();

        services.AddScoped<AuthService>();
        services.AddScoped<UserService>();
        services.AddScoped<CategoryService>();
        services.AddScoped<DocumentService>();
        services.AddScoped<ReportService>();

        return services;
    }
}
