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

PRINT 'Applied FileBase64 column, sp_User_GetByPan, sp_User_Login PAN lookup, and sp_Document_Upload base64.';
GO
