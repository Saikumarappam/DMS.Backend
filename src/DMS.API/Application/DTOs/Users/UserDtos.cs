namespace DMS.Application.DTOs.Users;

public class UserApprovalRequest
{
    public string Action { get; set; } = string.Empty;
    public string? Comments { get; set; }
}

public class UpdateProfileRequest
{
    public string Name { get; set; } = string.Empty;
    public string MobileNumber { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? Address { get; set; }
    public string? BusinessName { get; set; }
    public string? ContactPersonName { get; set; }
    public string? GSTNumber { get; set; }
    public bool ProfileCompleted { get; set; } = true;
}

public class UserDetailDto
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
    public string UserStatus { get; set; } = string.Empty;
    public bool ProfileCompleted { get; set; }
    public bool IsActive { get; set; }
    public string RoleName { get; set; } = string.Empty;
    public DateTime CreatedDate { get; set; }
}
