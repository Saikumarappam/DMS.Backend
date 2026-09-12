using System.Data;
using DMS.Application.Common;
using DMS.Application.Interfaces;
using DMS.Domain.Entities;
using Microsoft.Extensions.Configuration;

namespace DMS.Infrastructure.Repositories;

public class UserRepository : SqlRepositoryBase, IUserRepository
{
    public UserRepository(IConfiguration configuration) : base(configuration) { }

    public Task<DataSet> GetAllDataSetAsync(string? status, string? search) =>
        FetchSpDatasetAsync("User_GetAll", DbValue(status), DbValue(search));

    public Task<DataSet> GetUserByTypeDataSetAsync(string type, string value) =>
       FetchSpDatasetAsync("GetUserByType", type, value);

    public Task<DataSet> RegisterDataSetAsync(
        string name, string mobile, string email, string pan, string? address,
        string? businessName, string? contactPerson, string? gst,
        string passwordHash, string originalPassword) =>
        FetchSpDatasetAsync("User_Register",
            name, mobile, email, pan,
            DbValue(address), DbValue(businessName), DbValue(contactPerson), DbValue(gst),
            passwordHash, originalPassword, 2);

    public Task<DataSet> LoginDataSetAsync(string username, bool isPasswordValid, int maxAttempts = 5, int lockoutMinutes = 30) =>
        FetchSpDatasetAsync("User_Login", username, isPasswordValid, maxAttempts, lockoutMinutes);

    public Task<DataSet> ApproveRejectDataSetAsync(
        long userId, string action, string? comments, long actionBy) =>
        FetchSpDatasetAsync("User_ApproveReject",
            userId, action, DbValue(comments), actionBy);

    public Task<DataSet> ActivateDeactivateDataSetAsync(long userId, bool isActive, long actionBy) =>
        FetchSpDatasetAsync("User_ActivateDeactivate", userId, isActive, actionBy);

    public Task<DataSet> UpdateProfileDataSetAsync(
        long userId, string name, string mobile, string email, string? address,
        string? businessName, string? contactPerson, string? gst, bool profileCompleted, long modifiedBy) =>
        FetchSpDatasetAsync("User_UpdateProfile",
            userId, name, mobile, email, DbValue(address), DbValue(businessName),
            DbValue(contactPerson), DbValue(gst), profileCompleted, modifiedBy);

    public Task<DataSet> ChangePasswordDataSetAsync(long userId, string newHash, string originalPassword, long modifiedBy) =>
        FetchSpDatasetAsync("User_ChangePassword", userId, newHash, originalPassword, modifiedBy);

    public async Task<User?> GetUserByTypeAsync(string type,string value)
    {
        var ds = await GetUserByTypeDataSetAsync(type, value);
        return SpDataSetReader.MapFirstOrDefault<User>(ds);
    }
    public static User? MapUserFromLoginDataSet(DataSet ds) =>
        SpDataSetReader.MapFromTable<User>(ds, 1);

    private static (User? User, string? NotFoundMessage) ParseUserQueryResult(DataSet ds)
    {
        if (SpDataSetReader.TryParseInlineQueryResult(ds, out var success, out var message) && !success)
            return (null, string.IsNullOrWhiteSpace(message) ? "User not found." : message);

        return (SpDataSetReader.MapFirstOrDefault<User>(ds), null);
    }
}
