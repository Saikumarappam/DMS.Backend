using System.Diagnostics;

using System.Security.Claims;

using DMS.Application.Interfaces;



namespace DMS.API.Middleware;



public class ApiLoggingMiddleware

{

    private static readonly string[] IgnoredPrefixes = ["/swagger", "/favicon", "/health"];

    private readonly RequestDelegate _next;



    public ApiLoggingMiddleware(RequestDelegate next) => _next = next;



    public async Task InvokeAsync(HttpContext context, IApiLogService apiLog)

    {

        var path = context.Request.Path.Value ?? string.Empty;

        if (IgnoredPrefixes.Any(prefix => path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)))

        {

            await _next(context);

            return;

        }



        var stopwatch = Stopwatch.StartNew();

        await _next(context);

        stopwatch.Stop();



        try

        {

            var controller = context.GetEndpoint()?.Metadata

                .GetMetadata<Microsoft.AspNetCore.Mvc.Controllers.ControllerActionDescriptor>();



            apiLog.Log(

                controller?.ControllerName ?? "Http",

                $"{context.Request.Method} {path}",

                context.Request.QueryString.HasValue ? context.Request.QueryString.Value : null,

                $"Completed with HTTP {context.Response.StatusCode} in {stopwatch.ElapsedMilliseconds}ms",

                context.Response.StatusCode >= 400,

                context.User.FindFirstValue(ClaimTypes.NameIdentifier));

        }

        catch

        {

            // Logging must never break the request pipeline.

        }

    }

}

