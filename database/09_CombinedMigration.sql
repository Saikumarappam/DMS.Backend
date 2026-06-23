-- =============================================================================
-- DMS Combined Migration Script
-- =============================================================================
-- Combines all user/auth database changes:
--   - OriginalPassword column on Users
--   - Registration without password (credentials created on approval)
--   - Username = PAN number on approval
--   - PasswordHash + OriginalPassword stored together
--
-- Run on EXISTING database (safe to re-run):
--   1. Open SQL Server Management Studio (or sqlcmd)
--   2. Execute this entire script against DMS_DB
--
-- Replaces: 07_UserPasswordAndPanUsername.sql + 08_RegistrationWithoutPassword.sql
--           + sp_User_GetAll / sp_User_GetById / sp_User_ChangePassword updates
-- =============================================================================

USE DMS_DB;
GO

-- =============================================================================
-- TABLE: dbo.Users — add OriginalPassword column
-- =============================================================================
IF COL_LENGTH('dbo.Users', 'OriginalPassword') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD OriginalPassword NVARCHAR(100) NULL;
    PRINT 'Added column Users.OriginalPassword';
END
ELSE
    PRINT 'Column Users.OriginalPassword already exists — skipped.';
GO

-- =============================================================================
-- DATA FIX: pending users must not have login credentials yet
-- =============================================================================
UPDATE dbo.Users
SET Username = NULL,
    PasswordHash = NULL,
    OriginalPassword = NULL
WHERE UserStatus = 'PendingApproval'
  AND (Username IS NOT NULL OR PasswordHash IS NOT NULL OR OriginalPassword IS NOT NULL);

PRINT CONCAT('Cleared credentials for ', @@ROWCOUNT, ' pending user(s).');
GO

-- =============================================================================
-- DATA FIX: backfill admin OriginalPassword if missing
-- =============================================================================
UPDATE dbo.Users
SET OriginalPassword = 'Admin@123'
WHERE Username = 'admin'
  AND OriginalPassword IS NULL;

PRINT CONCAT('Backfilled admin OriginalPassword for ', @@ROWCOUNT, ' row(s).');
GO

-- =============================================================================
-- sp_User_Register
-- No password at registration. Username/credentials set on approval only.
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_Register', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_Register;
GO
CREATE PROCEDURE dbo.sp_User_Register
    @Name               NVARCHAR(150),
    @MobileNumber       NVARCHAR(15),
    @Email              NVARCHAR(256),
    @PANNumber          NVARCHAR(10),
    @Address            NVARCHAR(500) = NULL,
    @BusinessName       NVARCHAR(200) = NULL,
    @ContactPersonName  NVARCHAR(150) = NULL,
    @GSTNumber          NVARCHAR(15) = NULL,
    @RoleId             INT = 2,
    @UserId             BIGINT OUTPUT,
    @ResultCode         INT OUTPUT,
    @ResultMessage      NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @ResultCode = 0;
    SET @ResultMessage = 'Success';

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE MobileNumber = @MobileNumber)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Mobile number already registered.'; RETURN; END
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email)
    BEGIN SET @ResultCode = -2; SET @ResultMessage = 'Email already registered.'; RETURN; END
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE PANNumber = @PANNumber)
    BEGIN SET @ResultCode = -3; SET @ResultMessage = 'PAN number already registered.'; RETURN; END
    IF @GSTNumber IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Users WHERE GSTNumber = @GSTNumber)
    BEGIN SET @ResultCode = -4; SET @ResultMessage = 'GST number already registered.'; RETURN; END

    INSERT INTO dbo.Users (Name, MobileNumber, Email, PANNumber, Address, BusinessName,
        ContactPersonName, GSTNumber, RoleId, UserStatus, ProfileCompleted)
    VALUES (@Name, @MobileNumber, @Email, @PANNumber, @Address, @BusinessName,
        @ContactPersonName, @GSTNumber, @RoleId, 'PendingApproval', 0);

    SET @UserId = SCOPE_IDENTITY();

    INSERT INTO dbo.AuditLogs (UserId, Action, EntityName, EntityId, NewValues)
    VALUES (@UserId, 'Register', 'Users', CAST(@UserId AS NVARCHAR(50)),
        CONCAT('Name=', @Name, ';Email=', @Email, ';PAN=', @PANNumber));
END
GO
PRINT 'Created/updated sp_User_Register';
GO

-- =============================================================================
-- sp_User_ApproveReject
-- On Approve: Username = PAN, saves PasswordHash + OriginalPassword
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_ApproveReject', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_ApproveReject;
GO
CREATE PROCEDURE dbo.sp_User_ApproveReject
    @UserId             BIGINT,
    @Action             NVARCHAR(20),
    @Username           NVARCHAR(50) = NULL,
    @PasswordHash       NVARCHAR(500) = NULL,
    @OriginalPassword   NVARCHAR(100) = NULL,
    @Comments           NVARCHAR(500) = NULL,
    @ActionBy           BIGINT,
    @ResultCode         INT OUTPUT,
    @ResultMessage      NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @ResultCode = 0;
    SET @ResultMessage = 'Success';

    DECLARE @PANNumber NVARCHAR(10);

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'User not found.'; RETURN; END

    SELECT @PANNumber = PANNumber FROM dbo.Users WHERE UserId = @UserId;

    IF @Action = 'Approve'
    BEGIN
        IF @PasswordHash IS NULL OR @OriginalPassword IS NULL
        BEGIN SET @ResultCode = -2; SET @ResultMessage = 'Failed to generate login credentials.'; RETURN; END

        UPDATE dbo.Users SET Username = @PANNumber, PasswordHash = @PasswordHash,
            OriginalPassword = @OriginalPassword, UserStatus = 'Approved',
            ModifiedBy = @ActionBy, ModifiedDate = SYSUTCDATETIME()
        WHERE UserId = @UserId;
    END
    ELSE IF @Action = 'Reject'
    BEGIN
        UPDATE dbo.Users SET UserStatus = 'Rejected', ModifiedBy = @ActionBy, ModifiedDate = SYSUTCDATETIME()
        WHERE UserId = @UserId;
    END
    ELSE
    BEGIN SET @ResultCode = -4; SET @ResultMessage = 'Invalid action.'; RETURN; END

    INSERT INTO dbo.UserApprovalHistory (UserId, Action, Comments, ActionBy)
    VALUES (@UserId, @Action, @Comments, @ActionBy);

    INSERT INTO dbo.AuditLogs (UserId, Action, EntityName, EntityId, NewValues, CreatedDate)
    VALUES (@ActionBy, @Action, 'Users', CAST(@UserId AS NVARCHAR(50)), @Comments, SYSUTCDATETIME());
END
GO
PRINT 'Created/updated sp_User_ApproveReject';
GO

-- =============================================================================
-- sp_User_ChangePassword
-- Updates both PasswordHash and OriginalPassword
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_ChangePassword', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_ChangePassword;
GO
CREATE PROCEDURE dbo.sp_User_ChangePassword
    @UserId BIGINT,
    @NewPasswordHash NVARCHAR(500),
    @OriginalPassword NVARCHAR(100),
    @ModifiedBy BIGINT,
    @ResultCode INT OUTPUT,
    @ResultMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'User not found.'; RETURN; END

    UPDATE dbo.Users SET PasswordHash = @NewPasswordHash, OriginalPassword = @OriginalPassword,
        ModifiedBy = @ModifiedBy, ModifiedDate = SYSUTCDATETIME(),
        FailedLoginAttempts = 0, LockoutEnd = NULL
    WHERE UserId = @UserId;

    SET @ResultCode = 0;
    SET @ResultMessage = 'Password changed successfully.';
END
GO
PRINT 'Created/updated sp_User_ChangePassword';
GO

-- =============================================================================
-- sp_User_GetAll
-- Returns OriginalPassword for SuperAdmin user list
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_GetAll', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_GetAll;
GO
CREATE PROCEDURE dbo.sp_User_GetAll
    @UserStatus NVARCHAR(30) = NULL,
    @SearchTerm NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Name, u.MobileNumber, u.Email, u.PANNumber, u.BusinessName,
           u.ContactPersonName, u.GSTNumber, u.Username, u.OriginalPassword, u.UserStatus, u.ProfileCompleted,
           u.IsActive, u.CreatedDate, r.RoleName
    FROM dbo.Users u INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
    WHERE (@UserStatus IS NULL OR u.UserStatus = @UserStatus)
      AND (@SearchTerm IS NULL OR u.Name LIKE '%' + @SearchTerm + '%'
           OR u.Email LIKE '%' + @SearchTerm + '%' OR u.BusinessName LIKE '%' + @SearchTerm + '%')
    ORDER BY u.CreatedDate DESC;
END
GO
PRINT 'Created/updated sp_User_GetAll';
GO

-- =============================================================================
-- sp_User_GetById
-- Returns OriginalPassword for user detail
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_GetById', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_GetById;
GO
CREATE PROCEDURE dbo.sp_User_GetById
    @UserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Name, u.MobileNumber, u.Email, u.PANNumber, u.Address,
           u.BusinessName, u.ContactPersonName, u.GSTNumber, u.Username, u.OriginalPassword, u.UserStatus,
           u.ProfileCompleted, u.IsActive, u.CreatedDate, u.RoleId, r.RoleName
    FROM dbo.Users u INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
    WHERE u.UserId = @UserId;
END
GO
PRINT 'Created/updated sp_User_GetById';
GO

-- =============================================================================
-- DONE
-- =============================================================================
PRINT '=============================================================================';
PRINT 'DMS combined migration completed successfully.';
PRINT 'Updated objects:';
PRINT '  TABLE  : Users.OriginalPassword (column)';
PRINT '  SP     : sp_User_Register';
PRINT '  SP     : sp_User_ApproveReject';
PRINT '  SP     : sp_User_ChangePassword';
PRINT '  SP     : sp_User_GetAll';
PRINT '  SP     : sp_User_GetById';
PRINT '=============================================================================';
GO
