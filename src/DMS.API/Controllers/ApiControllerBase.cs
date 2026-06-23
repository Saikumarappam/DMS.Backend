using System.Security.Claims;

using DMS.Application.DTOs.Common;

using Microsoft.AspNetCore.Mvc;



namespace DMS.API.Controllers;



public abstract class ApiControllerBase : ControllerBase

{

    protected string? CurrentUserId => User.FindFirstValue(ClaimTypes.NameIdentifier);



    protected string? ClientIp => HttpContext.Connection.RemoteIpAddress?.ToString();



    protected bool TryGetCurrentUserId(out long userId, out Response? errorResponse)

    {

        errorResponse = null;

        userId = 0;



        if (string.IsNullOrWhiteSpace(CurrentUserId) || !long.TryParse(CurrentUserId, out userId))

        {

            errorResponse = ResponseHelper.UnauthorizedResponse();

            return false;

        }



        return true;

    }



    protected static Response Forbidden(string message) => ResponseHelper.ForbiddenResponse(message);

}

