-- Migration: registration without password; credentials created on approval
USE DMS_DB;
GO

IF COL_LENGTH('dbo.Users', 'OriginalPassword') IS NULL
    ALTER TABLE dbo.Users ADD OriginalPassword NVARCHAR(100) NULL;
GO

-- =============================================================================
-- sp_User_Register (no password at registration)
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

-- =============================================================================
-- sp_User_ApproveReject (creates username=PAN and password on approve)
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
