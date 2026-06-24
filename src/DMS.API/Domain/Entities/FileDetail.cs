namespace DMS.Domain.Entities;

public class FileDetail
{
    public long FileId { get; set; }
    public long ClientId { get; set; }
    public int CategoryId { get; set; }
    public string CategoryName { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public string OriginalFileName { get; set; } = string.Empty;
    public string FilePath { get; set; } = string.Empty;
    public string? FileBase64 { get; set; }
    public string FileExtension { get; set; } = string.Empty;
    public long FileSize { get; set; }
    public string Source { get; set; } = string.Empty;
    public string DocumentStatus { get; set; } = "Pending";
    public DateTime UploadDate { get; set; }
    public string? ClientName { get; set; }
    public string? BusinessName { get; set; }
}
