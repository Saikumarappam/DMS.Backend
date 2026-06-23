using System.Data;
using DMS.Application.Common;
using Helpers;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Repositories;

public class RefreshTokenRepository : SqlRepositoryBase, DMS.Application.Interfaces.IRefreshTokenRepository
{
    public RefreshTokenRepository(IConfiguration configuration) : base(configuration) { }

    public async Task SaveAsync(long userId, string token, DateTime expiresAt, string? ip)
    {
        await SqlHelper.ExecuteNonQueryAsync(_constr, "sp_RefreshToken_Save",
            userId, token, expiresAt, DbValue(ip));
    }

    public async Task<(long UserId, string Username)?> GetValidTokenAsync(string token)
    {
        var ds = await SqlHelper.ExecuteDatasetAsync(_constr, "sp_RefreshToken_Get", token);
        var row = SpDataSetReader.GetFirstDataRow(ds);
        if (row == null)
            return null;

        return (
            DataRowMapper.GetValue<long>(row, "UserId"),
            DataRowMapper.GetString(row, "Username") ?? "");
    }

    public async Task RevokeAsync(string token, string? replacedBy = null)
    {
        await SqlHelper.ExecuteNonQueryAsync(_constr, "sp_RefreshToken_Revoke", token, DbValue(replacedBy));
    }
}
