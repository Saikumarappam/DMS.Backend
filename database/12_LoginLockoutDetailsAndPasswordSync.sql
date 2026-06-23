-- =============================================================================
-- Login lockout details (attempt count + unlock time) and GetByUsername fields
-- for password hash auto-sync in the API.
-- =============================================================================

SET NOCOUNT ON;
GO

-- sp_User_GetByUsername — include fields needed for login password sync
IF OBJECT_ID('dbo.sp_User_GetByUsername', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_GetByUsername;
GO
CREATE PROCEDURE dbo.sp_User_GetByUsername
    @Username NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT u.UserId, u.Name, u.MobileNumber, u.Email, u.PANNumber, u.Address,
           u.BusinessName, u.ContactPersonName, u.GSTNumber, u.Username, u.PasswordHash,
           u.OriginalPassword, u.FailedLoginAttempts, u.LockoutEnd,
           u.UserStatus, u.ProfileCompleted, u.IsActive, u.CreatedDate, u.RoleId, r.RoleName
    FROM dbo.Users u
    INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
    WHERE u.Username = @Username;
END
GO

-- sp_User_Login — detailed lockout and failed-attempt messages
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

PRINT 'Updated sp_User_GetByUsername and sp_User_Login (lockout details + password sync fields).';
GO

-- sp_User_GetById — include PasswordHash for change-password verification
IF OBJECT_ID('dbo.sp_User_GetById', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_GetById;
GO
CREATE PROCEDURE dbo.sp_User_GetById
    @UserId BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UserId, u.Name, u.MobileNumber, u.Email, u.PANNumber, u.Address,
           u.BusinessName, u.ContactPersonName, u.GSTNumber, u.Username,
           u.PasswordHash, u.OriginalPassword, u.UserStatus,
           u.ProfileCompleted, u.IsActive, u.CreatedDate, u.RoleId, r.RoleName
    FROM dbo.Users u INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
    WHERE u.UserId = @UserId;
END
GO

PRINT 'Updated sp_User_GetById (PasswordHash for change-password verification).';
GO
