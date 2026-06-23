using Asp.Versioning;
using DMS.Application.DTOs.Common;
using DMS.Application.DTOs.Users;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/users")]
[Authorize]
public class UsersController : ApiControllerBase
{
    private readonly UserService _userService;

    public UsersController(UserService userService) => _userService = userService;

    [HttpGet]
    [Authorize(Roles = "SuperAdmin")]
    public Task<Response> GetUsers([FromQuery] string? status, [FromQuery] string? search) =>
        _userService.GetUsersAsync(status, search);

    [HttpGet("{id}")]
    public async Task<Response> GetUser(long id)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return error!;

        if (User.IsInRole("Client") && userId != id)
            return Forbidden("Access denied.");

        return await _userService.GetUserAsync(id);
    }

    [HttpGet("profile")]
    public Task<Response> GetProfile()
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _userService.GetUserAsync(userId);
    }

    [HttpPut("profile")]
    public Task<Response> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _userService.UpdateProfileAsync(userId, request);
    }

    [HttpPost("{id}/approval")]
    [Authorize(Roles = "SuperAdmin")]
    public Task<Response> ApproveReject(long id, [FromBody] UserApprovalRequest request)
    {
        if (!TryGetCurrentUserId(out var actionBy, out var error))
            return Task.FromResult(error!);

        return _userService.ApproveRejectAsync(id, request, actionBy);
    }

    [HttpPost("{id}/status")]
    [Authorize(Roles = "SuperAdmin")]
    public Task<Response> SetStatus(long id, [FromQuery] bool isActive)
    {
        if (!TryGetCurrentUserId(out var actionBy, out var error))
            return Task.FromResult(error!);

        return _userService.ActivateDeactivateAsync(id, isActive, actionBy);
    }
}
