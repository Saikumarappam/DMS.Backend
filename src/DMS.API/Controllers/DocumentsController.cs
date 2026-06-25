using Asp.Versioning;
using DMS.Application.DTOs.Common;
using DMS.Application.DTOs.Documents;
using DMS.Application.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DMS.API.Controllers;

/// <summary>Document upload, history, dashboard, and download.</summary>
[ApiController]
[ApiVersion("1.0")]
[Route("api/v{version:apiVersion}/documents")]
[Authorize]
[Tags("Documents")]
public class DocumentsController : ApiControllerBase
{
    private readonly DocumentService _documentService;

    public DocumentsController(DocumentService documentService) => _documentService = documentService;

    /// <summary>Upload a document (allowed types and size limits from FileStorage in appsettings).</summary>
    /// <remarks>Frontend: <c>UploadDocumentScreen</c> (<c>/upload</c>). Multipart form: categoryId, source, file.</remarks>
    [HttpPost("upload")]
    [Consumes("multipart/form-data")]
    [Produces("application/json")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
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

    /// <summary>Query document upload history with filters.</summary>
    /// <remarks>Frontend: <c>HistoryScreen</c> (<c>/history</c>). Client role is auto-scoped to own uploads.</remarks>
    [HttpGet("history")]
    [Produces("application/json")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
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

    /// <summary>Client dashboard: stats and recent uploads.</summary>
    /// <remarks>Frontend: <c>ClientDashboardScreen</c> (<c>/dashboard</c>). Client role only. data.Array0=user, Array1=stats, Array2=recent.</remarks>
    [HttpGet("dashboard")]
    [Authorize(Roles = "Client")]
    [Produces("application/json")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public Task<Response> GetDashboard()
    {
        if (!TryGetCurrentUserId(out var userId, out var error))
            return Task.FromResult(error!);

        return _documentService.GetDashboardAsync(userId);
    }

    /// <summary>Download a document as base64 in data.Array0.</summary>
    /// <remarks>Frontend: <c>HistoryScreen</c> download action. FilePath is never exposed.</remarks>
    [HttpGet("{id}/download")]
    [Produces("application/json")]
    [ProducesResponseType(typeof(Response), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(Response), StatusCodes.Status404NotFound)]
    public Task<Response> Download(long id) => _documentService.DownloadAsync(id);
}
