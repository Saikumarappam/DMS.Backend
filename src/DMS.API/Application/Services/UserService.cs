using DMS.API.Helpers;
using DMS.Application.Common;
using DMS.Application.DTOs.Common;
using DMS.Application.DTOs.Users;
using DMS.Application.Interfaces;

namespace DMS.Application.Services;

public class UserService
{
    private readonly IUserRepository _userRepo;
    private readonly INotificationService _notificationService;
    private readonly CommonFunctions _commonFunctions;
    private readonly SpResponseBuilder _spResponse;

    public UserService(
        IUserRepository userRepo,
        INotificationService notificationService,
        CommonFunctions commonFunctions,
        SpResponseBuilder spResponse)
    {
        _userRepo = userRepo;
        _notificationService = notificationService;
        _commonFunctions = commonFunctions;
        _spResponse = spResponse;
    }

    public async Task<Response> GetUsersAsync(string? status, string? search)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(status ?? "", search ?? "");
        try
        {
            var ds = await _userRepo.GetAllDataSetAsync(status, search);
            var resp = await _spResponse.FromDataSetAsync(ds);
            _commonFunctions.LogEvent("UserService.cs", "GetUsersAsync", paramsJson, resp.message, resp.status ? 0 : 0, "");
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("UserService.cs", "GetUsersAsync", paramsJson, ex.ToString(), 1, "");
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> GetUserAsync(long userId)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(userId);
        try
        {
            var ds = await _userRepo.GetByIdDataSetAsync(userId);
            var resp = await _spResponse.FromDataSetAsync(ds, "Success", "User not found.");
            if (!resp.status)
                resp.statuscode = ResponseHelper.NotFound;

            _commonFunctions.LogEvent("UserService.cs", "GetUserAsync", paramsJson, resp.message, resp.status ? 0 : 0, userId.ToString());
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("UserService.cs", "GetUserAsync", paramsJson, ex.ToString(), 1, userId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> ApproveRejectAsync(long userId, UserApprovalRequest request, long actionBy)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(userId, request.Action);
        try
        {
            var validationErrors = ValidationRules.ValidateApproval(request.Action);
            if (validationErrors.Count > 0)
            {
                var resp = ResponseHelper.Validation(string.Join("; ", validationErrors));
                resp.jsonstring = resp.message;
                _commonFunctions.LogEvent("UserService.cs", "ApproveRejectAsync", paramsJson, resp.message, 0, userId.ToString());
                return resp;
            }

            var ds = await _userRepo.ApproveRejectDataSetAsync(userId, request.Action, request.Comments, actionBy);
            var result = await _spResponse.FromCommandDataSetAsync(ds,
                request.Action == "Approve"
                    ? "User approved. They can sign in with their PAN number and the password chosen at registration."
                    : null);

            if (result.status && request.Action == "Approve")
            {
                var user = await _userRepo.GetByIdAsync(userId);
                if (user != null && ValidationRules.IsValidEmail(user.Email))
                {
                    var username = ValidationRules.NormalizePanNumber(user.PANNumber);
                    await _notificationService.SendApprovalNotificationAsync(user.Name, user.Email, username);
                }
            }

            _commonFunctions.LogEvent("UserService.cs", "ApproveRejectAsync", paramsJson, result.message, result.status ? 0 : 1, userId.ToString());
            return result;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("UserService.cs", "ApproveRejectAsync", paramsJson, ex.ToString(), 1, userId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> ActivateDeactivateAsync(long userId, bool isActive, long actionBy)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(userId, isActive);
        try
        {
            var ds = await _userRepo.ActivateDeactivateDataSetAsync(userId, isActive, actionBy);
            var resp = await _spResponse.FromCommandDataSetAsync(ds);
            _commonFunctions.LogEvent("UserService.cs", "ActivateDeactivateAsync", paramsJson, resp.message, resp.status ? 0 : 1, userId.ToString());
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("UserService.cs", "ActivateDeactivateAsync", paramsJson, ex.ToString(), 1, userId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }

    public async Task<Response> UpdateProfileAsync(long userId, UpdateProfileRequest request)
    {
        var paramsJson = await _commonFunctions.StringParamsToJson(userId);
        try
        {
            var ds = await _userRepo.UpdateProfileDataSetAsync(
                userId, request.Name, request.MobileNumber, request.Email,
                request.Address, request.BusinessName, request.ContactPersonName,
                request.GSTNumber, request.ProfileCompleted, userId);

            var resp = await _spResponse.FromCommandDataSetAsync(ds);
            _commonFunctions.LogEvent("UserService.cs", "UpdateProfileAsync", paramsJson, resp.message, resp.status ? 0 : 1, userId.ToString());
            return resp;
        }
        catch (Exception ex)
        {
            _commonFunctions.LogEvent("UserService.cs", "UpdateProfileAsync", paramsJson, ex.ToString(), 1, userId.ToString());
            return ResponseHelper.InternalErrorResponse();
        }
    }
}
