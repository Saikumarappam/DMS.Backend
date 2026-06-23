using System.Net;
using DMS.Application.DTOs.Common;
using DMS.Application.Interfaces;
using Microsoft.AspNetCore.Http;
using Serilog;

namespace DMS.API.Middleware;

public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;

    public ExceptionHandlingMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            Log.Error(ex, "Unhandled exception: {Message}", ex.Message);

            var apiLog = context.RequestServices.GetService<IApiLogService>();
            var controller = context.GetEndpoint()?.Metadata
                .GetMetadata<Microsoft.AspNetCore.Mvc.Controllers.ControllerActionDescriptor>();

            apiLog?.Log(
                controller?.ControllerName ?? "Http",
                controller?.ActionName ?? context.Request.Path.Value ?? "Unknown",
                context.Request.QueryString.HasValue ? context.Request.QueryString.Value : null,
                ex.ToString(),
                isError: true,
                context.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value);

            context.Response.StatusCode = (int)HttpStatusCode.InternalServerError;
            context.Response.ContentType = "application/json";

            await context.Response.WriteAsJsonAsync(ResponseHelper.InternalErrorResponse(
                "An internal error occurred while processing the request."));
        }
    }
}
