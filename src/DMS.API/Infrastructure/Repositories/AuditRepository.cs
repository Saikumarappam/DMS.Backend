using System.Data;
using DMS.Application.Common;
using DMS.Application.Interfaces;
using DMS.Domain.Entities;
using Helpers;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Repositories;

public class AuditRepository : SqlRepositoryBase, IAuditRepository
{
    public AuditRepository(IConfiguration configuration) : base(configuration) { }

    public async Task<DataSet> GetLogsDataSetAsync(DateTime? from, DateTime? to, long? userId) =>
        await FetchSpDatasetAsync("sp_AuditLog_Get", DbValue(from), DbValue(to), DbValue(userId));

    public async Task<List<AuditLog>> GetLogsAsync(DateTime? from, DateTime? to, long? userId)
    {
        var ds = await GetLogsDataSetAsync(from, to, userId);
        return SpDataSetReader.MapAll<AuditLog>(ds);
    }

    public async Task LogAsync(long? userId, string action, string entity, string? entityId, string? newValues, string? ip)
    {
        await SqlHelper.ExecuteNonQueryAsync(_constr, "sp_AuditLog_Insert",
            DbValue(userId), action, entity, DbValue(entityId), DbValue(newValues), DbValue(ip));
    }
}
