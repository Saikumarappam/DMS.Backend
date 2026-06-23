-- =============================================================================
-- DMS Apis-Aligned SP Results Migration
-- =============================================================================
-- All command SPs return DataSet (no OUTPUT params from C#):
--   Table 0: ResultCode, ResultMessage, RecordId (optional)
--   Table 1+: payload rows on success
--
-- Run after 09_CombinedMigration.sql on existing databases.
-- =============================================================================

USE DMS_DB;
GO

-- =============================================================================
-- sp_User_Register
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
    @RoleId             INT = 2
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success', @UserId BIGINT = NULL;

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE MobileNumber = @MobileNumber)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Mobile number already registered.'; GOTO Done; END
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email)
    BEGIN SET @ResultCode = -2; SET @ResultMessage = 'Email already registered.'; GOTO Done; END
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE PANNumber = @PANNumber)
    BEGIN SET @ResultCode = -3; SET @ResultMessage = 'PAN number already registered.'; GOTO Done; END
    IF @GSTNumber IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Users WHERE GSTNumber = @GSTNumber)
    BEGIN SET @ResultCode = -4; SET @ResultMessage = 'GST number already registered.'; GOTO Done; END

    INSERT INTO dbo.Users (Name, MobileNumber, Email, PANNumber, Address, BusinessName,
        ContactPersonName, GSTNumber, RoleId, UserStatus, ProfileCompleted)
    VALUES (@Name, @MobileNumber, @Email, @PANNumber, @Address, @BusinessName,
        @ContactPersonName, @GSTNumber, @RoleId, 'PendingApproval', 0);

    SET @UserId = SCOPE_IDENTITY();

    INSERT INTO dbo.AuditLogs (UserId, Action, EntityName, EntityId, NewValues)
    VALUES (@UserId, 'Register', 'Users', CAST(@UserId AS NVARCHAR(50)),
        CONCAT('Name=', @Name, ';Email=', @Email, ';PAN=', @PANNumber));

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @UserId AS RecordId;
END
GO

-- =============================================================================
-- sp_User_ApproveReject
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
    @ActionBy           BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success', @PANNumber NVARCHAR(10);

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'User not found.'; GOTO Done; END

    SELECT @PANNumber = PANNumber FROM dbo.Users WHERE UserId = @UserId;

    IF @Action = 'Approve'
    BEGIN
        IF @PasswordHash IS NULL OR @OriginalPassword IS NULL
        BEGIN SET @ResultCode = -2; SET @ResultMessage = 'Failed to generate login credentials.'; GOTO Done; END

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
    BEGIN SET @ResultCode = -4; SET @ResultMessage = 'Invalid action.'; GOTO Done; END

    INSERT INTO dbo.UserApprovalHistory (UserId, Action, Comments, ActionBy)
    VALUES (@UserId, @Action, @Comments, @ActionBy);

    INSERT INTO dbo.AuditLogs (UserId, Action, EntityName, EntityId, NewValues, CreatedDate)
    VALUES (@ActionBy, @Action, 'Users', CAST(@UserId AS NVARCHAR(50)), @Comments, SYSUTCDATETIME());

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @UserId AS RecordId;
END
GO

-- =============================================================================
-- sp_User_Login
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_Login', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_Login;
GO
CREATE PROCEDURE dbo.sp_User_Login
    @Username           NVARCHAR(50),
    @IsPasswordValid    BIT = 0,
    @MaxAttempts        INT = 5,
    @LockoutMinutes     INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success';
    DECLARE @UserId BIGINT, @Status NVARCHAR(30), @LockoutEnd DATETIME2, @FailedAttempts INT;
    DECLARE @NewAttempts INT, @LockoutEndText NVARCHAR(30);

    IF @MaxAttempts < 1 SET @MaxAttempts = 5;
    IF @LockoutMinutes < 1 SET @LockoutMinutes = 30;

    SELECT @UserId = UserId, @Status = UserStatus, @LockoutEnd = LockoutEnd,
           @FailedAttempts = FailedLoginAttempts
    FROM dbo.Users WHERE Username = @Username AND IsActive = 1;

    IF @UserId IS NULL
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Invalid username or password.'; GOTO Done; END

    IF @LockoutEnd IS NOT NULL AND @LockoutEnd > SYSUTCDATETIME()
    BEGIN
        SET @LockoutEndText = CONVERT(NVARCHAR(30), @LockoutEnd, 126);
        SET @ResultCode = -2;
        SET @ResultMessage = CONCAT(
            'Account is locked. Maximum login attempts (', @MaxAttempts,
            ') exceeded. Try again after ', @LockoutEndText, ' UTC.');
        GOTO Done;
    END

    IF @Status NOT IN ('Approved', 'Active')
    BEGIN SET @ResultCode = -3; SET @ResultMessage = 'Account is not approved for login.'; GOTO Done; END

    IF @IsPasswordValid = 0
    BEGIN
        SET @NewAttempts = @FailedAttempts + 1;
        UPDATE dbo.Users
        SET FailedLoginAttempts = @NewAttempts,
            LockoutEnd = CASE
                WHEN @NewAttempts >= @MaxAttempts THEN DATEADD(MINUTE, @LockoutMinutes, SYSUTCDATETIME())
                ELSE LockoutEnd
            END
        WHERE UserId = @UserId;

        IF @NewAttempts >= @MaxAttempts
        BEGIN
            SELECT @LockoutEnd = LockoutEnd FROM dbo.Users WHERE UserId = @UserId;
            SET @LockoutEndText = CONVERT(NVARCHAR(30), @LockoutEnd, 126);
            SET @ResultCode = -2;
            SET @ResultMessage = CONCAT(
                'Account locked. ', @MaxAttempts, ' failed login attempt(s) exceeded. ',
                'Try again after ', @LockoutEndText, ' UTC.');
        END
        ELSE
        BEGIN
            SET @ResultCode = -1;
            SET @ResultMessage = CONCAT(
                'Invalid username or password. Failed attempt ', @NewAttempts, ' of ', @MaxAttempts,
                '. ', @MaxAttempts - @NewAttempts, ' attempt(s) remaining before lockout.');
        END
        GOTO Done;
    END

    UPDATE dbo.Users SET FailedLoginAttempts = 0, LockoutEnd = NULL WHERE UserId = @UserId;

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @UserId AS RecordId;

    IF @ResultCode = 0 AND @UserId IS NOT NULL
    BEGIN
        SELECT u.UserId, u.Name, u.Email, u.MobileNumber, u.BusinessName, u.PANNumber, u.GSTNumber,
               u.UserStatus, u.ProfileCompleted, u.RoleId, r.RoleName, u.Username
        FROM dbo.Users u INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
        WHERE u.UserId = @UserId;
    END
END
GO

-- =============================================================================
-- sp_User_ActivateDeactivate
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_ActivateDeactivate', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_ActivateDeactivate;
GO
CREATE PROCEDURE dbo.sp_User_ActivateDeactivate
    @UserId BIGINT, @IsActive BIT, @ActionBy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success';

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'User not found.'; GOTO Done; END

    UPDATE dbo.Users SET IsActive = @IsActive,
        UserStatus = CASE WHEN @IsActive = 1 THEN 'Active' ELSE 'Deactivated' END,
        ModifiedBy = @ActionBy, ModifiedDate = SYSUTCDATETIME()
    WHERE UserId = @UserId;

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @UserId AS RecordId;
END
GO

-- =============================================================================
-- sp_User_UpdateProfile
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_UpdateProfile', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_UpdateProfile;
GO
CREATE PROCEDURE dbo.sp_User_UpdateProfile
    @UserId BIGINT, @Name NVARCHAR(150), @MobileNumber NVARCHAR(15), @Email NVARCHAR(256),
    @Address NVARCHAR(500) = NULL, @BusinessName NVARCHAR(200) = NULL,
    @ContactPersonName NVARCHAR(150) = NULL, @GSTNumber NVARCHAR(15) = NULL,
    @ProfileCompleted BIT = 1, @ModifiedBy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success';

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE MobileNumber = @MobileNumber AND UserId <> @UserId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Mobile number already in use.'; GOTO Done; END
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email AND UserId <> @UserId)
    BEGIN SET @ResultCode = -2; SET @ResultMessage = 'Email already in use.'; GOTO Done; END

    UPDATE dbo.Users SET Name = @Name, MobileNumber = @MobileNumber, Email = @Email,
        Address = @Address, BusinessName = @BusinessName, ContactPersonName = @ContactPersonName,
        GSTNumber = @GSTNumber, ProfileCompleted = @ProfileCompleted,
        ModifiedBy = @ModifiedBy, ModifiedDate = SYSUTCDATETIME()
    WHERE UserId = @UserId;

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @UserId AS RecordId;
END
GO

-- =============================================================================
-- sp_User_ChangePassword
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_ChangePassword', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_ChangePassword;
GO
CREATE PROCEDURE dbo.sp_User_ChangePassword
    @UserId BIGINT,
    @NewPasswordHash NVARCHAR(500),
    @OriginalPassword NVARCHAR(100),
    @ModifiedBy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Password changed successfully.';

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'User not found.'; GOTO Done; END

    UPDATE dbo.Users SET PasswordHash = @NewPasswordHash, OriginalPassword = @OriginalPassword,
        ModifiedBy = @ModifiedBy, ModifiedDate = SYSUTCDATETIME(),
        FailedLoginAttempts = 0, LockoutEnd = NULL
    WHERE UserId = @UserId;

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @UserId AS RecordId;
END
GO

-- =============================================================================
-- sp_Category_Add
-- =============================================================================
IF OBJECT_ID('dbo.sp_Category_Add', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Category_Add;
GO
CREATE PROCEDURE dbo.sp_Category_Add
    @CategoryName NVARCHAR(100), @Description NVARCHAR(300) = NULL, @CreatedBy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success', @CategoryId INT = NULL;

    IF EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryName = @CategoryName)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Category already exists.'; GOTO Done; END

    INSERT INTO dbo.FileCategories (CategoryName, Description, CreatedBy)
    VALUES (@CategoryName, @Description, @CreatedBy);
    SET @CategoryId = SCOPE_IDENTITY();

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @CategoryId AS RecordId;
END
GO

-- =============================================================================
-- sp_Category_Update
-- =============================================================================
IF OBJECT_ID('dbo.sp_Category_Update', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Category_Update;
GO
CREATE PROCEDURE dbo.sp_Category_Update
    @CategoryId INT, @CategoryName NVARCHAR(100), @Description NVARCHAR(300) = NULL, @ModifiedBy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success';

    IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryId = @CategoryId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Category not found.'; GOTO Done; END

    UPDATE dbo.FileCategories SET CategoryName = @CategoryName, Description = @Description,
        ModifiedBy = @ModifiedBy, ModifiedDate = SYSUTCDATETIME()
    WHERE CategoryId = @CategoryId;

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @CategoryId AS RecordId;
END
GO

-- =============================================================================
-- sp_Category_Delete
-- =============================================================================
IF OBJECT_ID('dbo.sp_Category_Delete', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Category_Delete;
GO
CREATE PROCEDURE dbo.sp_Category_Delete
    @CategoryId INT, @ModifiedBy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success';

    IF EXISTS (SELECT 1 FROM dbo.FileDetails WHERE CategoryId = @CategoryId AND IsActive = 1)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Category has associated documents.'; GOTO Done; END

    UPDATE dbo.FileCategories SET IsActive = 0, ModifiedBy = @ModifiedBy, ModifiedDate = SYSUTCDATETIME()
    WHERE CategoryId = @CategoryId;

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @CategoryId AS RecordId;
END
GO

-- =============================================================================
-- sp_Document_Upload
-- =============================================================================
IF OBJECT_ID('dbo.sp_Document_Upload', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Document_Upload;
GO
CREATE PROCEDURE dbo.sp_Document_Upload
    @ClientId BIGINT, @CategoryId INT, @CategoryName NVARCHAR(100),
    @FileName NVARCHAR(255), @OriginalFileName NVARCHAR(255), @FilePath NVARCHAR(500),
    @FileExtension NVARCHAR(20), @FileSize BIGINT, @Source NVARCHAR(50), @CreatedBy BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success', @FileId BIGINT = NULL;

    IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryId = @CategoryId AND IsActive = 1)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Invalid category.'; GOTO Done; END

    INSERT INTO dbo.FileDetails (ClientId, CategoryId, CategoryName, FileName, OriginalFileName,
        FilePath, FileExtension, FileSize, Source, CreatedBy)
    VALUES (@ClientId, @CategoryId, @CategoryName, @FileName, @OriginalFileName,
        @FilePath, @FileExtension, @FileSize, @Source, @CreatedBy);

    SET @FileId = SCOPE_IDENTITY();

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @FileId AS RecordId;
END
GO

PRINT 'Apis-aligned SP result migration completed.';
GO
