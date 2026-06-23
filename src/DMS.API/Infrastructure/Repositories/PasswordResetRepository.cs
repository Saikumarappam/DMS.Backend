using System.Data;
using DMS.Application.Common;
using DMS.Application.Interfaces;
using Helpers;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Repositories;

public class PasswordResetRepository : SqlRepositoryBase, IPasswordResetRepository
{
    public PasswordResetRepository(IConfiguration configuration) : base(configuration) { }

    public async Task SaveOtpAsync(long userId, string otpHash, DateTime expiresAt)
    {
        await SqlHelper.ExecuteNonQueryAsync(_constr, "sp_PasswordOtp_Save", userId, otpHash, expiresAt);
    }

    public async Task<PasswordOtpRecord?> GetActiveOtpAsync(long userId)
    {
        var ds = await SqlHelper.ExecuteDatasetAsync(_constr, "sp_PasswordOtp_GetActive", userId);
        var row = SpDataSetReader.GetFirstDataRow(ds);
        if (row == null)
            return null;

        return new PasswordOtpRecord(
            DataRowMapper.GetValue<long>(row, "OtpId"),
            DataRowMapper.GetValue<long>(row, "UserId"),
            DataRowMapper.GetString(row, "OtpHash") ?? "",
            DataRowMapper.GetValue<DateTime>(row, "ExpiresAt"),
            DataRowMapper.GetValue<int>(row, "AttemptCount"),
            DataRowMapper.GetValue<bool>(row, "IsVerified"),
            DataRowMapper.GetValue<bool>(row, "IsUsed"),
            DataRowMapper.GetString(row, "ResetSessionToken"),
            DataRowMapper.GetValue<DateTime?>(row, "SessionExpiresAt"));
    }

    public Task IncrementOtpAttemptAsync(long otpId) =>
        SqlHelper.ExecuteNonQueryAsync(_constr, "sp_PasswordOtp_IncrementAttempt", otpId);

    public Task SetOtpVerifiedAsync(long otpId, string resetSessionToken, DateTime sessionExpiresAt) =>
        SqlHelper.ExecuteNonQueryAsync(_constr, "sp_PasswordOtp_SetVerified", otpId, resetSessionToken, sessionExpiresAt);

    public async Task<PasswordOtpSessionRecord?> GetVerifiedSessionAsync(string email, string resetSessionToken)
    {
        var ds = await SqlHelper.ExecuteDatasetAsync(_constr, "sp_PasswordOtp_GetBySession", email, resetSessionToken);
        var row = SpDataSetReader.GetFirstDataRow(ds);
        if (row == null)
            return null;

        return new PasswordOtpSessionRecord(
            DataRowMapper.GetValue<long>(row, "OtpId"),
            DataRowMapper.GetValue<long>(row, "UserId"),
            DataRowMapper.GetString(row, "Email") ?? "",
            DataRowMapper.GetString(row, "Username"),
            DataRowMapper.GetValue<DateTime>(row, "SessionExpiresAt"));
    }

    public Task MarkOtpUsedAsync(long otpId) =>
        SqlHelper.ExecuteNonQueryAsync(_constr, "sp_PasswordOtp_MarkUsed", otpId);
}
