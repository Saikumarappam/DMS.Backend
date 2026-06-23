namespace DMS.Domain.Entities;

public class ReportItem
{
    public string Label { get; set; } = string.Empty;
    public int DocumentCount { get; set; }
    public long TotalSize { get; set; }
    public long? UserId { get; set; }
    public int? CategoryId { get; set; }
}
