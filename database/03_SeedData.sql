USE DMS_DB;
GO

-- Roles
IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = 'SuperAdmin')
    INSERT INTO dbo.Roles (RoleName, Description) VALUES ('SuperAdmin', 'System administrator with full access');

IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE RoleName = 'Client')
    INSERT INTO dbo.Roles (RoleName, Description) VALUES ('Client', 'Client user who uploads documents');

-- Default Super Admin (password: Admin@123 - change in production)
-- BCrypt hash for Admin@123
DECLARE @AdminRoleId INT = (SELECT RoleId FROM dbo.Roles WHERE RoleName = 'SuperAdmin');

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Username = 'admin')
    INSERT INTO dbo.Users (Name, MobileNumber, Email, PANNumber, Username, PasswordHash, OriginalPassword, RoleId,
        UserStatus, ProfileCompleted, IsActive, BusinessName)
    VALUES ('System Administrator', '9999999999', 'admin@dms.local', 'AAAAA0000A',
        'admin', '$2a$11$NBJ9B9Ze9KgfOzIglcyDsOytSH70RdVSgSbLonuqRVejLeGejklqa', 'Admin@123', @AdminRoleId,
        'Active', 1, 1, 'DMS Administration');

-- Default Categories
IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryName = 'Sales Documents')
    INSERT INTO dbo.FileCategories (CategoryName, Description) VALUES ('Sales Documents', 'Sales related documents');

IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryName = 'Purchase Documents')
    INSERT INTO dbo.FileCategories (CategoryName, Description) VALUES ('Purchase Documents', 'Purchase related documents');

IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryName = 'GST Documents')
    INSERT INTO dbo.FileCategories (CategoryName, Description) VALUES ('GST Documents', 'GST related documents');

IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryName = 'Bank Statements')
    INSERT INTO dbo.FileCategories (CategoryName, Description) VALUES ('Bank Statements', 'Bank statement documents');

IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryName = 'Other Documents')
    INSERT INTO dbo.FileCategories (CategoryName, Description) VALUES ('Other Documents', 'Miscellaneous documents');

GO
