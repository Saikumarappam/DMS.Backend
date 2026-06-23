-- Apis-aligned infrastructure: EventDetails + INSEventDetails and supporting SPs

USE DMS_DB;

GO



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

-- sp_User_GetByUsername

-- =============================================================================

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



-- =============================================================================

-- sp_User_GetByEmail

-- =============================================================================

IF OBJECT_ID('dbo.sp_User_GetByEmail', 'P') IS NOT NULL DROP PROCEDURE dbo.sp_User_GetByEmail;

GO



CREATE PROCEDURE dbo.sp_User_GetByEmail

    @Email NVARCHAR(256)

AS

BEGIN

    SET NOCOUNT ON;



    SELECT u.UserId, u.Name, u.MobileNumber, u.Email, u.PANNumber, u.Address,

           u.BusinessName, u.ContactPersonName, u.GSTNumber, u.Username, u.PasswordHash,

           u.UserStatus, u.ProfileCompleted, u.IsActive, u.CreatedDate, u.RoleId, r.RoleName

    FROM dbo.Users u

    INNER JOIN dbo.Roles r ON u.RoleId = r.RoleId

    WHERE u.Email = @Email;

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

