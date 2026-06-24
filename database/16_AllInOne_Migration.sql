-- =============================================================================
-- 16_AllInOne_Migration.sql
-- Single script: all DMS.API database updates aligned with src/DMS.API code.
-- Safe to re-run on existing DMS_DB (idempotent checks throughout).
--
-- Prerequisites: 01_Schema.sql and 03_SeedData.sql already applied.
-- Do NOT re-run 01_Schema.sql when using this on an existing database.
--
-- Includes: user/auth schema fixes, OTP flow, API logging, command SPs
-- (SELECT ResultCode — no OUTPUT), query SPs, login lockout, FileBase64,
-- document upload/history without FilePath in API payloads.
-- =============================================================================
USE DMS_DB;
GO
SET NOCOUNT ON;
GO
-- ========== User schema & data fixes ==========
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

GO

-- ========== Password OTP flow ==========
-- OTP-based forgot password flow (extends Users / PasswordResetTokens pattern)

IF OBJECT_ID('dbo.PasswordResetOtps', 'U') IS NULL

BEGIN

    CREATE TABLE dbo.PasswordResetOtps (

        OtpId               BIGINT IDENTITY(1,1) NOT NULL,

        UserId              BIGINT NOT NULL,

        OtpHash             NVARCHAR(500) NOT NULL,

        ExpiresAt           DATETIME2 NOT NULL,

        AttemptCount        INT NOT NULL DEFAULT 0,

        IsVerified          BIT NOT NULL DEFAULT 0,

        IsUsed              BIT NOT NULL DEFAULT 0,

        ResetSessionToken   NVARCHAR(500) NULL,

        SessionExpiresAt    DATETIME2 NULL,

        CreatedAt           DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_PasswordResetOtps PRIMARY KEY CLUSTERED (OtpId),

        CONSTRAINT FK_PasswordResetOtps_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId)

    );



    CREATE NONCLUSTERED INDEX IX_PasswordResetOtps_UserId_Active

        ON dbo.PasswordResetOtps(UserId, IsUsed, CreatedAt DESC);

END

GO



IF OBJECT_ID('dbo.sp_PasswordOtp_Save', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_PasswordOtp_Save;

GO

CREATE PROCEDURE dbo.sp_PasswordOtp_Save

    @UserId     BIGINT,

    @OtpHash    NVARCHAR(500),

    @ExpiresAt  DATETIME2

AS

BEGIN

    SET NOCOUNT ON;

    UPDATE dbo.PasswordResetOtps SET IsUsed = 1

    WHERE UserId = @UserId AND IsUsed = 0;



    INSERT INTO dbo.PasswordResetOtps (UserId, OtpHash, ExpiresAt)

    VALUES (@UserId, @OtpHash, @ExpiresAt);

END

GO



IF OBJECT_ID('dbo.sp_PasswordOtp_GetActive', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_PasswordOtp_GetActive;

GO

CREATE PROCEDURE dbo.sp_PasswordOtp_GetActive

    @UserId BIGINT

AS

BEGIN

    SET NOCOUNT ON;



    SELECT TOP 1 OtpId, UserId, OtpHash, ExpiresAt, AttemptCount, IsVerified, IsUsed,

           ResetSessionToken, SessionExpiresAt

    FROM dbo.PasswordResetOtps

    WHERE UserId = @UserId AND IsUsed = 0

    ORDER BY CreatedAt DESC;

END

GO



IF OBJECT_ID('dbo.sp_PasswordOtp_IncrementAttempt', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_PasswordOtp_IncrementAttempt;

GO

CREATE PROCEDURE dbo.sp_PasswordOtp_IncrementAttempt

    @OtpId BIGINT

AS

BEGIN

    SET NOCOUNT ON;

    UPDATE dbo.PasswordResetOtps SET AttemptCount = AttemptCount + 1 WHERE OtpId = @OtpId;

END

GO



IF OBJECT_ID('dbo.sp_PasswordOtp_SetVerified', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_PasswordOtp_SetVerified;

GO

CREATE PROCEDURE dbo.sp_PasswordOtp_SetVerified

    @OtpId              BIGINT,

    @ResetSessionToken  NVARCHAR(500),

    @SessionExpiresAt   DATETIME2

AS

BEGIN

    SET NOCOUNT ON;

    UPDATE dbo.PasswordResetOtps

    SET IsVerified = 1, ResetSessionToken = @ResetSessionToken, SessionExpiresAt = @SessionExpiresAt

    WHERE OtpId = @OtpId;

END

GO



IF OBJECT_ID('dbo.sp_PasswordOtp_GetBySession', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_PasswordOtp_GetBySession;

GO

CREATE PROCEDURE dbo.sp_PasswordOtp_GetBySession

    @Email              NVARCHAR(256),

    @ResetSessionToken  NVARCHAR(500)

AS

BEGIN

    SET NOCOUNT ON;



    SELECT o.OtpId, o.UserId, o.IsVerified, o.IsUsed, o.SessionExpiresAt, u.Email, u.Username

    FROM dbo.PasswordResetOtps o

    INNER JOIN dbo.Users u ON u.UserId = o.UserId

    WHERE u.Email = @Email

      AND o.ResetSessionToken = @ResetSessionToken

      AND o.IsVerified = 1

      AND o.IsUsed = 0

      AND o.SessionExpiresAt > SYSUTCDATETIME();

END

GO



IF OBJECT_ID('dbo.sp_PasswordOtp_MarkUsed', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_PasswordOtp_MarkUsed;

GO

CREATE PROCEDURE dbo.sp_PasswordOtp_MarkUsed

    @OtpId BIGINT

AS

BEGIN

    SET NOCOUNT ON;

    UPDATE dbo.PasswordResetOtps SET IsUsed = 1 WHERE OtpId = @OtpId;

END

GO

GO

-- ========== API event logging ==========
-- Apis-aligned infrastructure: EventDetails + INSEventDetails and supporting SPs

-- =============================================================================

-- EventDetails + INSEventDetails (same pattern as Apis project)

-- =============================================================================

IF OBJECT_ID('dbo.EventDetails', 'U') IS NULL

BEGIN

    CREATE TABLE dbo.EventDetails (

        EventId           BIGINT IDENTITY(1,1) NOT NULL,

        EventSource       NVARCHAR(200) NOT NULL,

        EventProcedure    NVARCHAR(200) NOT NULL,

        Param             NVARCHAR(MAX) NULL,

        EventDescription  NVARCHAR(MAX) NULL,

        IsError           INT NOT NULL DEFAULT 0,

        UniqueId          NVARCHAR(100) NULL,

        CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_EventDetails PRIMARY KEY CLUSTERED (EventId)

    );



    CREATE NONCLUSTERED INDEX IX_EventDetails_CreatedAt ON dbo.EventDetails(CreatedAt);

    CREATE NONCLUSTERED INDEX IX_EventDetails_IsError ON dbo.EventDetails(IsError);

    CREATE NONCLUSTERED INDEX IX_EventDetails_EventSource ON dbo.EventDetails(EventSource);

END

GO



IF OBJECT_ID('dbo.INSEventDetails', 'P') IS NOT NULL DROP PROCEDURE dbo.INSEventDetails;

GO



CREATE PROCEDURE dbo.INSEventDetails

    @EventSource       NVARCHAR(200),

    @EventProcedure    NVARCHAR(200),

    @Param             NVARCHAR(MAX) = NULL,

    @EventDescription  NVARCHAR(MAX) = NULL,

    @IsError           INT = 0,

    @UniqueId          NVARCHAR(100) = NULL

AS

BEGIN

    SET NOCOUNT ON;



    INSERT INTO dbo.EventDetails (EventSource, EventProcedure, Param, EventDescription, IsError, UniqueId)

    VALUES (@EventSource, @EventProcedure, @Param, @EventDescription, @IsError, @UniqueId);

END

GO



-- =============================================================================

-- sp_AuditLog_Insert

-- =============================================================================

IF OBJECT_ID('dbo.sp_AuditLog_Insert', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_AuditLog_Insert;

GO



CREATE PROCEDURE dbo.sp_AuditLog_Insert

    @UserId      BIGINT = NULL,

    @Action      NVARCHAR(100),

    @EntityName  NVARCHAR(100),

    @EntityId    NVARCHAR(50) = NULL,

    @NewValues   NVARCHAR(MAX) = NULL,

    @IpAddress   NVARCHAR(50) = NULL

AS

BEGIN

    SET NOCOUNT ON;



    INSERT INTO dbo.AuditLogs (UserId, Action, EntityName, EntityId, NewValues, IpAddress)

    VALUES (@UserId, @Action, @EntityName, @EntityId, @NewValues, @IpAddress);

END

GO

GO

-- ========== Command SPs (ResultCode pattern) ==========
-- =============================================================================
-- DMS Apis-Aligned SP Results Migration
-- =============================================================================
-- All command SPs return DataSet (no OUTPUT params from C#):
--   Table 0: ResultCode, ResultMessage, RecordId (optional)
--   Table 1+: payload rows on success
--
-- Run after 09_CombinedMigration.sql on existing databases.
-- =============================================================================

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

PRINT 'Apis-aligned SP result migration completed.';
GO

GO

-- ========== Query SPs (inline ResultCode) ==========
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

GO

-- ========== FileBase64 + login PAN lookup ==========
-- =============================================================================
-- FileDetails base64 backup + login PAN lookup when Username is not assigned
-- =============================================================================

SET NOCOUNT ON;
GO

IF COL_LENGTH('dbo.FileDetails', 'FileBase64') IS NULL
    ALTER TABLE dbo.FileDetails ADD FileBase64 NVARCHAR(MAX) NULL;
GO

-- sp_User_GetByPan — lookup by PAN when username is not yet assigned
IF OBJECT_ID('dbo.sp_User_GetByPan', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_GetByPan;
GO
CREATE PROCEDURE dbo.sp_User_GetByPan
    @PANNumber NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM dbo.Users
        WHERE PANNumber = @PANNumber
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
        WHERE u.PANNumber = @PANNumber;
    END
    ELSE
    BEGIN
        SELECT
            0 AS ResultCode,
            'User not found with the provided PAN number.' AS Message;
    END
END
GO

-- sp_User_Login — detect PAN match when Username is null/empty before generic failure
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
    BEGIN
        SELECT @UserId = UserId, @Status = UserStatus, @LockoutEnd = LockoutEnd,
               @FailedAttempts = FailedLoginAttempts
        FROM dbo.Users
        WHERE PANNumber = @Username AND IsActive = 1
          AND (Username IS NULL OR LTRIM(RTRIM(Username)) = '');

        IF @UserId IS NOT NULL
        BEGIN
            SET @ResultCode = -3;
            SET @ResultMessage = CASE
                WHEN @Status IN ('PendingApproval', 'Rejected')
                    THEN 'Your account is pending admin approval. Login access has not been assigned yet.'
                ELSE 'Login access is not configured for this account. Please contact support.'
            END;
            GOTO Done;
        END

        SET @ResultCode = -1;
        SET @ResultMessage = 'Invalid username or password.';
        GOTO Done;
    END

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

-- sp_Document_Upload — persist base64 backup alongside file path
PRINT 'Applied FileBase64 column, sp_User_GetByPan, sp_User_Login PAN lookup, and sp_Document_Upload base64.';
GO

GO

-- ========== Document API (no FilePath in responses) ==========
-- =============================================================================
-- Exclude FilePath from document query responses exposed to the frontend.
-- Frontend downloads files via base64 only.
-- =============================================================================

SET NOCOUNT ON;
GO

IF OBJECT_ID('dbo.sp_Document_GetHistory', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Document_GetHistory;
GO
CREATE PROCEDURE dbo.sp_Document_GetHistory
    @ClientId BIGINT = NULL,
    @CategoryId INT = NULL,
    @FromDate DATETIME2 = NULL,
    @ToDate DATETIME2 = NULL,
    @SearchFileName NVARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.FileId, f.ClientId, f.CategoryId, f.CategoryName, f.FileName, f.OriginalFileName,
           f.FileExtension, f.FileSize, f.Source, f.DocumentStatus, f.UploadDate,
           u.Name AS ClientName, u.BusinessName
    FROM dbo.FileDetails f
    INNER JOIN dbo.Users u ON f.ClientId = u.UserId
    WHERE f.IsActive = 1
      AND (@ClientId IS NULL OR f.ClientId = @ClientId)
      AND (@CategoryId IS NULL OR f.CategoryId = @CategoryId)
      AND (@FromDate IS NULL OR f.UploadDate >= @FromDate)
      AND (@ToDate IS NULL OR f.UploadDate <= @ToDate)
      AND (@SearchFileName IS NULL OR f.OriginalFileName LIKE '%' + @SearchFileName + '%')
    ORDER BY f.UploadDate DESC;
END
GO

-- sp_Document_Upload — success payload without FilePath
IF OBJECT_ID('dbo.sp_Document_Upload', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Document_Upload;
GO
CREATE PROCEDURE dbo.sp_Document_Upload
    @ClientId BIGINT, @CategoryId INT, @CategoryName NVARCHAR(100),
    @FileName NVARCHAR(255), @OriginalFileName NVARCHAR(255), @FilePath NVARCHAR(500),
    @FileExtension NVARCHAR(20), @FileSize BIGINT, @Source NVARCHAR(50), @CreatedBy BIGINT,
    @FileBase64 NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ResultCode INT = 0, @ResultMessage NVARCHAR(500) = 'Success', @FileId BIGINT = NULL;

    IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryId = @CategoryId AND IsActive = 1)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Invalid category.'; GOTO Done; END

    INSERT INTO dbo.FileDetails (ClientId, CategoryId, CategoryName, FileName, OriginalFileName,
        FilePath, FileExtension, FileSize, Source, FileBase64, CreatedBy)
    VALUES (@ClientId, @CategoryId, @CategoryName, @FileName, @OriginalFileName,
        @FilePath, @FileExtension, @FileSize, @Source, @FileBase64, @CreatedBy);

    SET @FileId = SCOPE_IDENTITY();

Done:
    SELECT @ResultCode AS ResultCode, @ResultMessage AS ResultMessage, @FileId AS RecordId;

    IF @ResultCode = 0 AND @FileId IS NOT NULL
    BEGIN
        SELECT FileId, ClientId, CategoryId, CategoryName, FileName, OriginalFileName,
               FileExtension, FileSize, Source, DocumentStatus, UploadDate
        FROM dbo.FileDetails
        WHERE FileId = @FileId;
    END
END
GO

PRINT 'Updated sp_Document_GetHistory and sp_Document_Upload to exclude FilePath from API payloads.';
GO

GO

-- ========== Supporting SPs ==========
-- =============================================================================
-- sp_Category_GetAll
-- =============================================================================
IF OBJECT_ID('dbo.sp_Category_GetAll', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Category_GetAll;
GO
CREATE PROCEDURE dbo.sp_Category_GetAll
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CategoryId, CategoryName, Description, IsActive, CreatedDate
    FROM dbo.FileCategories
    WHERE @IncludeInactive = 1 OR IsActive = 1
    ORDER BY CategoryName;
END
GO

-- =============================================================================
-- sp_Document_GetById
-- =============================================================================
IF OBJECT_ID('dbo.sp_Document_GetById', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Document_GetById;
GO
CREATE PROCEDURE dbo.sp_Document_GetById
    @FileId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT f.*, u.Name AS ClientName, u.BusinessName
    FROM dbo.FileDetails f INNER JOIN dbo.Users u ON f.ClientId = u.UserId
    WHERE f.FileId = @FileId AND f.IsActive = 1;
END
GO

-- =============================================================================
-- sp_Document_GetDashboardStats
-- =============================================================================
IF OBJECT_ID('dbo.sp_Document_GetDashboardStats', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Document_GetDashboardStats;
GO
CREATE PROCEDURE dbo.sp_Document_GetDashboardStats
    @ClientId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*) AS TotalDocuments,
        SUM(CASE WHEN DocumentStatus = 'Pending' THEN 1 ELSE 0 END) AS PendingDocuments,
        SUM(CASE WHEN DocumentStatus = 'Approved' THEN 1 ELSE 0 END) AS ApprovedDocuments
    FROM dbo.FileDetails WHERE ClientId = @ClientId AND IsActive = 1;

    SELECT TOP 5 FileId, OriginalFileName, CategoryName, UploadDate, DocumentStatus, Source
    FROM dbo.FileDetails WHERE ClientId = @ClientId AND IsActive = 1
    ORDER BY UploadDate DESC;
END
GO

-- =============================================================================
-- sp_RefreshToken_Save
-- =============================================================================
IF OBJECT_ID('dbo.sp_RefreshToken_Save', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_RefreshToken_Save;
GO
CREATE PROCEDURE dbo.sp_RefreshToken_Save
    @UserId BIGINT, @Token NVARCHAR(500), @ExpiresAt DATETIME2, @CreatedByIp NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.RefreshTokens (UserId, Token, ExpiresAt, CreatedByIp)
    VALUES (@UserId, @Token, @ExpiresAt, @CreatedByIp);
END
GO

-- =============================================================================
-- sp_RefreshToken_Get
-- =============================================================================
IF OBJECT_ID('dbo.sp_RefreshToken_Get', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_RefreshToken_Get;
GO
CREATE PROCEDURE dbo.sp_RefreshToken_Get
    @Token NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT rt.*, u.Username, u.UserStatus, u.IsActive
    FROM dbo.RefreshTokens rt INNER JOIN dbo.Users u ON rt.UserId = u.UserId
    WHERE rt.Token = @Token AND rt.RevokedAt IS NULL AND rt.ExpiresAt > SYSUTCDATETIME();
END
GO

-- =============================================================================
-- sp_RefreshToken_Revoke
-- =============================================================================
IF OBJECT_ID('dbo.sp_RefreshToken_Revoke', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_RefreshToken_Revoke;
GO
CREATE PROCEDURE dbo.sp_RefreshToken_Revoke
    @Token NVARCHAR(500), @ReplacedByToken NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.RefreshTokens SET RevokedAt = SYSUTCDATETIME(), ReplacedByToken = @ReplacedByToken
    WHERE Token = @Token;
END
GO

-- =============================================================================
-- sp_Report_DailyUploads
-- =============================================================================
IF OBJECT_ID('dbo.sp_Report_DailyUploads', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Report_DailyUploads;
GO
CREATE PROCEDURE dbo.sp_Report_DailyUploads
    @FromDate DATETIME2, @ToDate DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CAST(UploadDate AS DATE) AS UploadDay, COUNT(*) AS DocumentCount, SUM(FileSize) AS TotalSize
    FROM dbo.FileDetails WHERE IsActive = 1 AND UploadDate BETWEEN @FromDate AND @ToDate
    GROUP BY CAST(UploadDate AS DATE) ORDER BY UploadDay;
END
GO

-- =============================================================================
-- sp_Report_MonthlyUploads
-- =============================================================================
IF OBJECT_ID('dbo.sp_Report_MonthlyUploads', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Report_MonthlyUploads;
GO
CREATE PROCEDURE dbo.sp_Report_MonthlyUploads
    @Year INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MONTH(UploadDate) AS UploadMonth, COUNT(*) AS DocumentCount, SUM(FileSize) AS TotalSize
    FROM dbo.FileDetails WHERE IsActive = 1 AND YEAR(UploadDate) = @Year
    GROUP BY MONTH(UploadDate) ORDER BY UploadMonth;
END
GO

-- =============================================================================
-- sp_Report_UserWise
-- =============================================================================
IF OBJECT_ID('dbo.sp_Report_UserWise', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Report_UserWise;
GO
CREATE PROCEDURE dbo.sp_Report_UserWise
    @FromDate DATETIME2 = NULL, @ToDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Name, u.BusinessName, COUNT(f.FileId) AS DocumentCount, SUM(f.FileSize) AS TotalSize
    FROM dbo.Users u
    INNER JOIN dbo.FileDetails f ON u.UserId = f.ClientId AND f.IsActive = 1
    WHERE (@FromDate IS NULL OR f.UploadDate >= @FromDate)
      AND (@ToDate IS NULL OR f.UploadDate <= @ToDate)
    GROUP BY u.UserId, u.Name, u.BusinessName
    ORDER BY DocumentCount DESC;
END
GO

-- =============================================================================
-- sp_Report_CategoryWise
-- =============================================================================
IF OBJECT_ID('dbo.sp_Report_CategoryWise', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Report_CategoryWise;
GO
CREATE PROCEDURE dbo.sp_Report_CategoryWise
    @FromDate DATETIME2 = NULL, @ToDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.CategoryId, c.CategoryName, COUNT(f.FileId) AS DocumentCount, SUM(f.FileSize) AS TotalSize
    FROM dbo.FileCategories c
    INNER JOIN dbo.FileDetails f ON c.CategoryId = f.CategoryId AND f.IsActive = 1
    WHERE (@FromDate IS NULL OR f.UploadDate >= @FromDate)
      AND (@ToDate IS NULL OR f.UploadDate <= @ToDate)
    GROUP BY c.CategoryId, c.CategoryName
    ORDER BY DocumentCount DESC;
END
GO

-- =============================================================================
-- sp_AuditLog_Get
-- =============================================================================
IF OBJECT_ID('dbo.sp_AuditLog_Get', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_AuditLog_Get;
GO
CREATE PROCEDURE dbo.sp_AuditLog_Get
    @FromDate DATETIME2 = NULL, @ToDate DATETIME2 = NULL, @UserId BIGINT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT a.AuditLogId, a.UserId, a.Action, a.EntityName, a.EntityId,
           a.OldValues, a.NewValues, a.IpAddress, a.CreatedDate, u.Name AS UserName
    FROM dbo.AuditLogs a LEFT JOIN dbo.Users u ON a.UserId = u.UserId
    WHERE (@FromDate IS NULL OR a.CreatedDate >= @FromDate)
      AND (@ToDate IS NULL OR a.CreatedDate <= @ToDate)
      AND (@UserId IS NULL OR a.UserId = @UserId)
    ORDER BY a.CreatedDate DESC;
END
GO

GO

PRINT '=============================================================================';
PRINT '16_AllInOne_Migration completed successfully.';
PRINT '=============================================================================';
GO
