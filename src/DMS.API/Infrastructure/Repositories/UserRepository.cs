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
        FetchSpDatasetAsync("sp_User_GetAll", DbValue(status), DbValue(search));

    public Task<DataSet> GetByIdDataSetAsync(long userId) =>
        FetchSpDatasetAsync("sp_User_GetById", userId);

    public Task<DataSet> GetByUsernameDataSetAsync(string username) =>
        FetchSpDatasetAsync("sp_User_GetByUsername", username);

    public Task<DataSet> GetByPanDataSetAsync(string panNumber) =>
        FetchSpDatasetAsync("sp_User_GetByPan", panNumber);

    public Task<DataSet> GetByEmailDataSetAsync(string email) =>
        FetchSpDatasetAsync("sp_User_GetByEmail", email);

    public Task<DataSet> RegisterDataSetAsync(
        string name, string mobile, string email, string pan, string? address,
        string? businessName, string? contactPerson, string? gst) =>
        FetchSpDatasetAsync("sp_User_Register",
            name, mobile, email, pan,
            DbValue(address), DbValue(businessName), DbValue(contactPerson), DbValue(gst), 2);

    public Task<DataSet> LoginDataSetAsync(string username, bool isPasswordValid, int maxAttempts = 5, int lockoutMinutes = 30) =>
        FetchSpDatasetAsync("sp_User_Login", username, isPasswordValid, maxAttempts, lockoutMinutes);

    public Task<DataSet> ApproveRejectDataSetAsync(
        long userId, string action, string? username, string? passwordHash, string? originalPassword, string? comments, long actionBy) =>
        FetchSpDatasetAsync("sp_User_ApproveReject",
            userId, action, DbValue(username), DbValue(passwordHash), DbValue(originalPassword), DbValue(comments), actionBy);

    public Task<DataSet> ActivateDeactivateDataSetAsync(long userId, bool isActive, long actionBy) =>
        FetchSpDatasetAsync("sp_User_ActivateDeactivate", userId, isActive, actionBy);

    public Task<DataSet> UpdateProfileDataSetAsync(
        long userId, string name, string mobile, string email, string? address,
        string? businessName, string? contactPerson, string? gst, bool profileCompleted, long modifiedBy) =>
        FetchSpDatasetAsync("sp_User_UpdateProfile",
            userId, name, mobile, email, DbValue(address), DbValue(businessName),
            DbValue(contactPerson), DbValue(gst), profileCompleted, modifiedBy);

    public Task<DataSet> ChangePasswordDataSetAsync(long userId, string newHash, string originalPassword, long modifiedBy) =>
        FetchSpDatasetAsync("sp_User_ChangePassword", userId, newHash, originalPassword, modifiedBy);

    public async Task<User?> GetByUsernameAsync(string username)
    {
        var ds = await GetByUsernameDataSetAsync(username);
        return SpDataSetReader.MapFirstOrDefault<User>(ds);
    }

    public async Task<(User? User, string? NotFoundMessage)> GetByUsernameOrMessageAsync(string username)
    {
        var ds = await GetByUsernameDataSetAsync(username);
        return ParseUserQueryResult(ds);
    }

    public async Task<User?> GetByPanAsync(string panNumber)
    {
        var ds = await GetByPanDataSetAsync(panNumber);
        return SpDataSetReader.MapFirstOrDefault<User>(ds);
    }

    public async Task<User?> GetByIdAsync(long userId)
    {
        var ds = await GetByIdDataSetAsync(userId);
        return SpDataSetReader.MapFirstOrDefault<User>(ds);
    }

    public async Task<User?> GetByEmailAsync(string email)
    {
        var ds = await GetByEmailDataSetAsync(email);
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
