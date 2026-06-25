using Asp.Versioning;
using DMS.Application.DTOs.Common;
using DMS.Application.Interfaces;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

/// <summary>Admin reporting and audit logs.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/reports")]
[Authorize(Roles = "SuperAdmin")]
[Tags("Reports")]
[Produces("application/json")]
public class ReportsController : ApiControllerBase
{
    private readonly ReportService _reportService;
    private readonly IAuditRepository _auditRepo;

    public ReportsController(ReportService reportService, IAuditRepository auditRepo)
    {
        _reportService = reportService;
        _auditRepo = auditRepo;
    }

    /// <summary>Daily upload counts for a date range.</summary>
    /// <remarks>Frontend: <c>ReportsScreen</c> (<c>/admin/reports</c>)</remarks>
    [HttpGet("daily")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public Task<Response> Daily([FromQuery] DateTime fromDate, [FromQuery] DateTime toDate) =>
        _reportService.GetDailyAsync(fromDate, toDate);

    /// <summary>Monthly upload counts for a calendar year.</summary>
    /// <remarks>Frontend: <c>ReportsScreen</c></remarks>
    [HttpGet("monthly")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    public Task<Response> Monthly([FromQuery] int year) =>
        _reportService.GetMonthlyAsync(year);

    /// <summary>Upload statistics grouped by client.</summary>
    /// <remarks>Frontend: <c>ReportsScreen</c></remarks>
    [HttpGet("user-wise")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    public Task<Response> UserWise([FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate) =>
        _reportService.GetUserWiseAsync(fromDate, toDate);

    /// <summary>Upload statistics grouped by category.</summary>
    /// <remarks>Frontend: <c>ReportsScreen</c></remarks>
    [HttpGet("category-wise")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    public Task<Response> CategoryWise([FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate) =>
        _reportService.GetCategoryWiseAsync(fromDate, toDate);

    /// <summary>System audit log entries with optional date and user filters.</summary>
    /// <remarks>Frontend: <c>ReportsScreen</c> audit tab</remarks>
    [HttpGet("audit-logs")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    public Task<Response> AuditLogs(
        [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, [FromQuery] long? userId) =>
        _reportService.GetAuditLogsAsync(fromDate, toDate, userId, _auditRepo);
}
