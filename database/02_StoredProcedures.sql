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
    @PasswordHash       NVARCHAR(500),
    @OriginalPassword   NVARCHAR(100),
    @RoleId             INT = 2,
    @UserId             BIGINT OUTPUT,
    @ResultCode         INT OUTPUT,
    @ResultMessage      NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @ResultCode = 0;
    SET @ResultMessage = 'Success';

    IF @PasswordHash IS NULL OR @OriginalPassword IS NULL
    BEGIN 
    SET @ResultCode = -5; SET @ResultMessage = 'Password is required.'; 
    RETURN;
    END

    IF EXISTS (SELECT 1 FROM dbo.Users WHERE MobileNumber = @MobileNumber)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Mobile number already registered.'; RETURN; END
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email)
    BEGIN SET @ResultCode = -2; SET @ResultMessage = 'Email already registered.'; RETURN; END
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE PANNumber = @PANNumber)
    BEGIN SET @ResultCode = -3; SET @ResultMessage = 'PAN number already registered.'; RETURN; END
    IF @GSTNumber IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Users WHERE GSTNumber = @GSTNumber)
    BEGIN SET @ResultCode = -4; SET @ResultMessage = 'GST number already registered.'; RETURN; END

    INSERT INTO dbo.Users (Name, MobileNumber, Email, PANNumber,Address, BusinessName,
        ContactPersonName, GSTNumber,UserName, PasswordHash, OriginalPassword, RoleId, UserStatus, ProfileCompleted)
    VALUES (@Name, @MobileNumber, @Email, @PANNumber, @Address, @BusinessName,
        @ContactPersonName, @GSTNumber,@PANNumber, @PasswordHash, @OriginalPassword, @RoleId, 'PendingApproval', 0);

    SET @UserId = SCOPE_IDENTITY();

    INSERT INTO dbo.AuditLogs (UserId, Action, EntityName, EntityId, NewValues)
    VALUES (@UserId, 'Register', 'Users', CAST(@UserId AS NVARCHAR(50)),
        CONCAT('Name=', @Name, ';Email=', @Email, ';PAN=', @PANNumber));
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
    DECLARE @PasswordHash NVARCHAR(500);

    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'User not found.'; RETURN; END

    SELECT @PANNumber = PANNumber, @PasswordHash = PasswordHash
    FROM dbo.Users WHERE UserId = @UserId;

    IF @Action = 'Approve'
    BEGIN
        IF @PasswordHash IS NULL
        BEGIN SET @ResultCode = -2; SET @ResultMessage = 'Registration password not found. User must register with a password.'; RETURN; END

        UPDATE dbo.Users SET Username = @PANNumber, UserStatus = 'Approved',
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

-- =============================================================================
-- sp_User_Login
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_Login', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_Login;
GO
CREATE PROCEDURE dbo.sp_User_Login
    @Username           NVARCHAR(50),
    @PasswordHash       NVARCHAR(500) = NULL,
    @IsPasswordValid    BIT = 0,
    @ResultCode         INT OUTPUT,
    @ResultMessage      NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @ResultCode = 0;
    SET @ResultMessage = 'Success';

    DECLARE @UserId BIGINT, @Status NVARCHAR(30), @Attempts INT, @LockoutEnd DATETIME2, @StoredHash NVARCHAR(500);

    SELECT @UserId = UserId, @Status = UserStatus, @Attempts = FailedLoginAttempts,
           @LockoutEnd = LockoutEnd, @StoredHash = PasswordHash
    FROM dbo.Users WHERE Username = @Username AND IsActive = 1;

    IF @UserId IS NULL
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Invalid username or password.'; RETURN; END

    IF @LockoutEnd IS NOT NULL AND @LockoutEnd > SYSUTCDATETIME()
    BEGIN SET @ResultCode = -2; SET @ResultMessage = 'Account is locked. Try again later.'; RETURN; END

    IF @Status NOT IN ('Approved', 'Active')
    BEGIN SET @ResultCode = -3; SET @ResultMessage = 'Account is not approved for login.'; RETURN; END

    IF @IsPasswordValid = 0
    BEGIN
        UPDATE dbo.Users SET FailedLoginAttempts = FailedLoginAttempts + 1,
            LockoutEnd = CASE WHEN FailedLoginAttempts + 1 >= 5 THEN DATEADD(MINUTE, 30, SYSUTCDATETIME()) ELSE LockoutEnd END
        WHERE UserId = @UserId;
        SET @ResultCode = -1; SET @ResultMessage = 'Invalid username or password.'; RETURN;
    END

    UPDATE dbo.Users SET FailedLoginAttempts = 0, LockoutEnd = NULL WHERE UserId = @UserId;

    SELECT u.UserId, u.Name, u.Email, u.MobileNumber, u.BusinessName, u.PANNumber, u.GSTNumber,
           u.UserStatus, u.ProfileCompleted, u.RoleId, r.RoleName, u.Username
    FROM dbo.Users u INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId
    WHERE u.UserId = @UserId;
END
GO

-- =============================================================================
-- sp_User_GetAll
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

-- =============================================================================
-- sp_User_GetById
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

-- =============================================================================
-- sp_User_ActivateDeactivate
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_ActivateDeactivate', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_ActivateDeactivate;
GO
CREATE PROCEDURE dbo.sp_User_ActivateDeactivate
    @UserId BIGINT, @IsActive BIT, @ActionBy BIGINT,
    @ResultCode INT OUTPUT, @ResultMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @UserId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'User not found.'; RETURN; END

    UPDATE dbo.Users SET IsActive = @IsActive, UserStatus = CASE WHEN @IsActive = 1 THEN 'Active' ELSE 'Deactivated' END,
        ModifiedBy = @ActionBy, ModifiedDate = SYSUTCDATETIME() WHERE UserId = @UserId;
    SET @ResultCode = 0; SET @ResultMessage = 'Success';
END
GO

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
-- sp_Category_Add
-- =============================================================================
IF OBJECT_ID('dbo.sp_Category_Add', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Category_Add;
GO
CREATE PROCEDURE dbo.sp_Category_Add
    @CategoryName NVARCHAR(100), @Description NVARCHAR(300) = NULL, @CreatedBy BIGINT,
    @CategoryId INT OUTPUT, @ResultCode INT OUTPUT, @ResultMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryName = @CategoryName)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Category already exists.'; RETURN; END

    INSERT INTO dbo.FileCategories (CategoryName, Description, CreatedBy)
    VALUES (@CategoryName, @Description, @CreatedBy);
    SET @CategoryId = SCOPE_IDENTITY();
    SET @ResultCode = 0; SET @ResultMessage = 'Success';
END
GO

-- =============================================================================
-- sp_Category_Update
-- =============================================================================
IF OBJECT_ID('dbo.sp_Category_Update', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Category_Update;
GO
CREATE PROCEDURE dbo.sp_Category_Update
    @CategoryId INT, @CategoryName NVARCHAR(100), @Description NVARCHAR(300) = NULL,
    @ModifiedBy BIGINT, @ResultCode INT OUTPUT, @ResultMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryId = @CategoryId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Category not found.'; RETURN; END

    UPDATE dbo.FileCategories SET CategoryName = @CategoryName, Description = @Description,
        ModifiedBy = @ModifiedBy, ModifiedDate = SYSUTCDATETIME()
    WHERE CategoryId = @CategoryId;
    SET @ResultCode = 0; SET @ResultMessage = 'Success';
END
GO

-- =============================================================================
-- sp_Category_Delete
-- =============================================================================
IF OBJECT_ID('dbo.sp_Category_Delete', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_Category_Delete;
GO
CREATE PROCEDURE dbo.sp_Category_Delete
    @CategoryId INT, @ModifiedBy BIGINT,
    @ResultCode INT OUTPUT, @ResultMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.FileDetails WHERE CategoryId = @CategoryId AND IsActive = 1)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Category has associated documents.'; RETURN; END

    UPDATE dbo.FileCategories SET IsActive = 0, ModifiedBy = @ModifiedBy, ModifiedDate = SYSUTCDATETIME()
    WHERE CategoryId = @CategoryId;
    SET @ResultCode = 0; SET @ResultMessage = 'Success';
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
    @FileExtension NVARCHAR(20), @FileSize BIGINT, @Source NVARCHAR(50), @CreatedBy BIGINT,
    @FileId BIGINT OUTPUT, @ResultCode INT OUTPUT, @ResultMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.FileCategories WHERE CategoryId = @CategoryId AND IsActive = 1)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Invalid category.'; RETURN; END

    INSERT INTO dbo.FileDetails (ClientId, CategoryId, CategoryName, FileName, OriginalFileName,
        FilePath, FileExtension, FileSize, Source, CreatedBy)
    VALUES (@ClientId, @CategoryId, @CategoryName, @FileName, @OriginalFileName,
        @FilePath, @FileExtension, @FileSize, @Source, @CreatedBy);

    SET @FileId = SCOPE_IDENTITY();
    SET @ResultCode = 0; SET @ResultMessage = 'Success';
END
GO

-- =============================================================================
-- sp_Document_GetHistory
-- =============================================================================
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
           f.FilePath, f.FileExtension, f.FileSize, f.Source, f.DocumentStatus, f.UploadDate,
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
-- sp_User_UpdateProfile
-- =============================================================================
IF OBJECT_ID('dbo.sp_User_UpdateProfile', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_UpdateProfile;
GO
CREATE PROCEDURE dbo.sp_User_UpdateProfile
    @UserId BIGINT, @Name NVARCHAR(150), @MobileNumber NVARCHAR(15), @Email NVARCHAR(256),
    @Address NVARCHAR(500) = NULL, @BusinessName NVARCHAR(200) = NULL,
    @ContactPersonName NVARCHAR(150) = NULL, @GSTNumber NVARCHAR(15) = NULL,
    @ProfileCompleted BIT = 1, @ModifiedBy BIGINT,
    @ResultCode INT OUTPUT, @ResultMessage NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE MobileNumber = @MobileNumber AND UserId <> @UserId)
    BEGIN SET @ResultCode = -1; SET @ResultMessage = 'Mobile number already in use.'; RETURN; END
    IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email AND UserId <> @UserId)
    BEGIN SET @ResultCode = -2; SET @ResultMessage = 'Email already in use.'; RETURN; END

    UPDATE dbo.Users SET Name = @Name, MobileNumber = @MobileNumber, Email = @Email,
        Address = @Address, BusinessName = @BusinessName, ContactPersonName = @ContactPersonName,
        GSTNumber = @GSTNumber, ProfileCompleted = @ProfileCompleted,
        ModifiedBy = @ModifiedBy, ModifiedDate = SYSUTCDATETIME()
    WHERE UserId = @UserId;
    SET @ResultCode = 0; SET @ResultMessage = 'Success';
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

-- =============================================================================
-- sp_PasswordReset_Save
-- =============================================================================
IF OBJECT_ID('dbo.sp_PasswordReset_Save', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_PasswordReset_Save;
GO
CREATE PROCEDURE dbo.sp_PasswordReset_Save
    @UserId BIGINT, @Token NVARCHAR(500), @ExpiresAt DATETIME2
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.PasswordResetTokens SET IsUsed = 1 WHERE UserId = @UserId AND IsUsed = 0;
    INSERT INTO dbo.PasswordResetTokens (UserId, Token, ExpiresAt) VALUES (@UserId, @Token, @ExpiresAt);
END
GO

-- =============================================================================
-- sp_PasswordReset_Get
-- =============================================================================
IF OBJECT_ID('dbo.sp_PasswordReset_Get', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_PasswordReset_Get;
GO
CREATE PROCEDURE dbo.sp_PasswordReset_Get
    @Token NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT UserId FROM dbo.PasswordResetTokens
    WHERE Token = @Token AND IsUsed = 0 AND ExpiresAt > SYSUTCDATETIME();
END
GO

-- =============================================================================
-- sp_PasswordReset_MarkUsed
-- =============================================================================
IF OBJECT_ID('dbo.sp_PasswordReset_MarkUsed', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_PasswordReset_MarkUsed;
GO
CREATE PROCEDURE dbo.sp_PasswordReset_MarkUsed
    @Token NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.PasswordResetTokens SET IsUsed = 1 WHERE Token = @Token;
END
GO
