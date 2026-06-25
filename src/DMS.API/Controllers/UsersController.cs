using Asp.Versioning;
using DMS.Application.DTOs.Common;
using DMS.Application.DTOs.Users;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

/// <summary>User profile and admin user management.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/users")]
[Authorize]
[Tags("Users")]
[Produces("application/json")]
public class UsersController : ApiControllerBase
{
    private readonly UserService _userService;

    public UsersController(UserService userService) => _userService = userService;

    /// <summary>List users with optional status and search filters.</summary>
    /// <remarks>Frontend: <c>UserManagementScreen</c> (<c>/admin/users</c>). SuperAdmin only.</remarks>
    [HttpGet]
    [Authorize(Roles = "SuperAdmin")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public Task<Response> GetUsers([FromQuery] string? status, [FromQuery] string? search) =>
        _userService.GetUsersAsync(status, search);

    /// <summary>Get a user by ID.</summary>
    /// <remarks>SuperAdmin: any user. Client: own ID only. Not yet wired in frontend.</remarks>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<Response> GetUser(long id)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return error!;

        if (User.IsInRole("Client") && userId != id)
            return Forbidden("Access denied.");

        return await _userService.GetUserAsync(id);
    }

    /// <summary>Get the authenticated user's profile.</summary>
    /// <remarks>Frontend: <c>ProfileScreen</c>, <c>authProvider.refreshProfile</c></remarks>
    [HttpGet("profile")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public Task<Response> GetProfile()
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _userService.GetUserAsync(userId);
    }

    /// <summary>Update the authenticated user's profile.</summary>
    /// <remarks>Frontend: <c>ProfileScreen</c> (<c>/profile</c>)</remarks>
    [HttpPut("profile")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public Task<Response> UpdateProfile([FromBody] UpdateProfileRequest request)
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _userService.UpdateProfileAsync(userId, request);
    }

    /// <summary>Approve or reject a pending user registration.</summary>
    /// <remarks>Frontend: <c>UserManagementScreen</c> approve/reject dialogs. SuperAdmin only. Action: Approve | Reject.</remarks>
    [HttpPost("{id}/approval")]
    [Authorize(Roles = "SuperAdmin")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public Task<Response> ApproveReject(long id, [FromBody] UserApprovalRequest request)
    {
        if (!TryGetCurrentUserId(out var actionBy, out var error))
            return Task.FromResult(error!);

        return _userService.ApproveRejectAsync(id, request, actionBy);
    }

    /// <summary>Activate or deactivate a user account.</summary>
    /// <remarks>Frontend: <c>UserManagementScreen</c> status toggle. SuperAdmin only.</remarks>
    [HttpPost("{id}/status")]
    [Authorize(Roles = "SuperAdmin")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public Task<Response> SetStatus(long id, [FromQuery] bool isActive)
    {
        if (!TryGetCurrentUserId(out var actionBy, out var error))
            return Task.FromResult(error!);

        return _userService.ActivateDeactivateAsync(id, isActive, actionBy);
    }
}
