namespace DMS.Domain.Entities;

public class User
{
    public long UserId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string MobileNumber { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PANNumber { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? BusinessName { get; set; }
    public string? ContactPersonName { get; set; }
    public string? GSTNumber { get; set; }
    public string? Username { get; set; }
    public string? PasswordHash { get; set; }
    public string? OriginalPassword { get; set; }
    public int RoleId { get; set; }
    public string RoleName { get; set; } = string.Empty;
    public string UserStatus { get; set; } = "PendingApproval";
    public bool ProfileCompleted { get; set; }
    public int FailedLoginAttempts { get; set; }
    public DateTime? LockoutEnd { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedDate { get; set; }

    /// <summary>
    /// Columns returned by SPs that do not map to a typed property are stored here.
    /// </summary>
    public Dictionary<string, object?> AdditionalFields { get; set; } = new();
}
