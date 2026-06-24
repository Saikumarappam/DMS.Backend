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
