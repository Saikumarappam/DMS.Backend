-- =============================================================================
-- Query SP pattern (Apis-style): inline ResultCode/Message in result set.
-- ResultCode 1 = found, 0 = not found. API maps rows dynamically via DataSetToJson.
-- =============================================================================

SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.sp_User_GetByUsername', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_GetByUsername;
GO
CREATE PROCEDURE dbo.sp_User_GetByUsername
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM dbo.Users
        WHERE Username = @Username
          AND IsActive = 1
    )
    BEGIN
        SELECT
            u.UserId,
            u.Name,
            u.MobileNumber,
            u.Email,
            u.PANNumber,
            u.Address,
            u.BusinessName,
            u.ContactPersonName,
            u.GSTNumber,
            u.Username,
            u.PasswordHash,
            u.OriginalPassword,
            u.FailedLoginAttempts,
            u.LockoutEnd,
            u.UserStatus,
            u.ProfileCompleted,
            u.IsActive,
            u.CreatedDate,
            u.RoleId,
            r.RoleName,
            1 AS ResultCode,
            'User found successfully.' AS Message
        FROM dbo.Users u
        INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
        WHERE u.Username = @Username;
    END
    ELSE
    BEGIN
        SELECT
            0 AS ResultCode,
            'User not found with the provided username.' AS Message;
    END
END
GO

IF OBJECT_ID('dbo.sp_User_GetById', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_GetById;
GO
CREATE PROCEDURE dbo.sp_User_GetById
    @UserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
    BEGIN
        SELECT
            u.UserId,
            u.Name,
            u.MobileNumber,
            u.Email,
            u.PANNumber,
            u.Address,
            u.BusinessName,
            u.ContactPersonName,
            u.GSTNumber,
            u.Username,
            u.PasswordHash,
            u.OriginalPassword,
            u.UserStatus,
            u.ProfileCompleted,
            u.IsActive,
            u.CreatedDate,
            u.RoleId,
            r.RoleName,
            1 AS ResultCode,
            'User found successfully.' AS Message
        FROM dbo.Users u
        INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
        WHERE u.UserId = @UserId;
    END
    ELSE
    BEGIN
        SELECT
            0 AS ResultCode,
            'User not found.' AS Message;
    END
END
GO

IF OBJECT_ID('dbo.sp_User_GetByEmail', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_GetByEmail;
GO
CREATE PROCEDURE dbo.sp_User_GetByEmail
    @Email NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email AND IsActive = 1)
    BEGIN
        SELECT
            u.UserId,
            u.Name,
            u.MobileNumber,
            u.Email,
            u.PANNumber,
            u.Address,
            u.BusinessName,
            u.ContactPersonName,
            u.GSTNumber,
            u.Username,
            u.PasswordHash,
            u.OriginalPassword,
            u.FailedLoginAttempts,
            u.LockoutEnd,
            u.UserStatus,
            u.ProfileCompleted,
            u.IsActive,
            u.CreatedDate,
            u.RoleId,
            r.RoleName,
            1 AS ResultCode,
            'User found successfully.' AS Message
        FROM dbo.Users u
        INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
        WHERE u.Email = @Email;
    END
    ELSE
    BEGIN
        SELECT
            0 AS ResultCode,
            'User not found with the provided email.' AS Message;
    END
END
GO

PRINT 'Updated sp_User_GetByUsername, sp_User_GetById, sp_User_GetByEmail to inline query result pattern.';
GO
