namespace DMS.Domain.Entities;

public class DashboardStats
{
    public int TotalDocuments { get; set; }
    public int PendingDocuments { get; set; }
    public int ApprovedDocuments { get; set; }
    public List<FileDetail> RecentUploads { get; set; } = new();
}
