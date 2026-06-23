namespace DMS.Domain.Entities;

public class AuditLog
{
    public long AuditLogId { get; set; }
    public long? UserId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string EntityName { get; set; } = string.Empty;
    public string? EntityId { get; set; }
    public string? OldValues { get; set; }
    public string? NewValues { get; set; }
    public string? IpAddress { get; set; }
    public DateTime CreatedDate { get; set; }
    public string? UserName { get; set; }
}
