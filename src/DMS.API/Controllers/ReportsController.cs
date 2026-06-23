using Asp.Versioning;
using DMS.Application.DTOs.Common;
using DMS.Application.Interfaces;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/reports")]
[Authorize(Roles = "SuperAdmin")]
public class ReportsController : ApiControllerBase
{
    private readonly ReportService _reportService;
    private readonly IAuditRepository _auditRepo;

    public ReportsController(ReportService reportService, IAuditRepository auditRepo)
    {
        _reportService = reportService;
        _auditRepo = auditRepo;
    }

    [HttpGet("daily")]
    public Task<Response> Daily([FromQuery] DateTime fromDate, [FromQuery] DateTime toDate) =>
        _reportService.GetDailyAsync(fromDate, toDate);

    [HttpGet("monthly")]
    public Task<Response> Monthly([FromQuery] int year) =>
        _reportService.GetMonthlyAsync(year);

    [HttpGet("user-wise")]
    public Task<Response> UserWise([FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate) =>
        _reportService.GetUserWiseAsync(fromDate, toDate);

    [HttpGet("category-wise")]
    public Task<Response> CategoryWise([FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate) =>
        _reportService.GetCategoryWiseAsync(fromDate, toDate);

    [HttpGet("audit-logs")]
    public Task<Response> AuditLogs(
        [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, [FromQuery] long? userId) =>
        _reportService.GetAuditLogsAsync(fromDate, toDate, userId, _auditRepo);
}
