using Asp.Versioning;
using DMS.Application.DTOs.Common;
using DMS.Application.DTOs.Documents;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/documents")]
[Authorize]
public class DocumentsController : ApiControllerBase
{
    private readonly DocumentService _documentService;

    public DocumentsController(DocumentService documentService) => _documentService = documentService;

    [HttpPost("upload")]
    public async Task<Response> Upload(
        [FromForm] int categoryId,
        [FromForm] string source,
        IFormFile file)
    {
        if (file == null || file.Length == 0)
            return ResponseHelper.Validation("No file uploaded.");

        if (!TryGetCurrentUserId(out var userId, out var error))
            return error!;

        using var stream = file.OpenReadStream();
        return await _documentService.UploadAsync(userId, categoryId, source, stream, file.FileName);
    }

    [HttpGet("history")]
    public Task<Response> GetHistory([FromQuery] DocumentHistoryFilter filter)
    {
        if (User.IsInRole("Client"))
        {
            if (!TryGetCurrentUserId(out var userId, out var error))
                return Task.FromResult(error!);

            filter.ClientId = userId;
        }

        return _documentService.GetHistoryAsync(filter);
    }

    [HttpGet("dashboard")]
    [Authorize(Roles = "Client")]
    public Task<Response> GetDashboard()
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _documentService.GetDashboardAsync(userId);
    }

    [HttpGet("{id}/download")]
    public async Task<IActionResult> Download(long id)
    {
        var result = await _documentService.DownloadAsync(id);
        if (result.Error != null)
            return Ok(result.Error);

        return File(result.Stream!, result.ContentType!, result.FileName);
    }
}
