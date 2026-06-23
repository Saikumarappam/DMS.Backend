using DMS.Application.DTOs.Common;

namespace DMS.Application.DTOs.Documents;

public record DocumentDownloadResult(Response? Error, Stream? Stream, string? ContentType, string? FileName);

public class DocumentUploadRequest
{
    public int CategoryId { get; set; }
    public string Source { get; set; } = string.Empty;
}

public class DocumentDto
{
    public long FileId { get; set; }
    public long ClientId { get; set; }
    public int CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public string OriginalFileName { get; set; } = string.Empty;
    public string FileExtension { get; set; } = string.Empty;
    public long FileSize { get; set; }
    public string Source { get; set; } = string.Empty;
    public string DocumentStatus { get; set; } = string.Empty;
    public DateTime UploadDate { get; set; }
    public string? ClientName { get; set; }
    public string? BusinessName { get; set; }
}

public class DocumentHistoryFilter
{
    public long? ClientId { get; set; }
    public int? CategoryId { get; set; }
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
    public string? SearchFileName { get; set; }
}

public class DashboardDto
{
    public string Name { get; set; } = string.Empty;
    public string? BusinessName { get; set; }
    public int TotalDocuments { get; set; }
    public int PendingDocuments { get; set; }
    public int ApprovedDocuments { get; set; }
    public List<DocumentDto> RecentUploads { get; set; } = new();
}
