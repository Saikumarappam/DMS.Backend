-- =============================================================================
-- DMS Database Schema
-- Document Management System - SQL Server
-- =============================================================================

USE master;
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'DMS_DB')
    CREATE DATABASE DMS_DB;
GO

USE DMS_DB;
GO

-- =============================================================================
-- ROLES
-- =============================================================================
IF OBJECT_ID('dbo.Roles', 'U') IS NOT NULL DROP TABLE dbo.Roles;
CREATE TABLE dbo.Roles (
    RoleId          INT IDENTITY(1,1) NOT NULL,
    RoleName        NVARCHAR(50) NOT NULL,
    Description     NVARCHAR(200) NULL,
    IsActive        BIT NOT NULL DEFAULT 1,
    CreatedDate     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Roles PRIMARY KEY CLUSTERED (RoleId),
    CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName)
);

-- =============================================================================
-- USERS
-- =============================================================================
IF OBJECT_ID('dbo.Users', 'U') IS NOT NULL DROP TABLE dbo.Users;
CREATE TABLE dbo.Users (
    UserId              BIGINT IDENTITY(1,1) NOT NULL,
    Name                NVARCHAR(150) NOT NULL,
    MobileNumber        NVARCHAR(15) NOT NULL,
    Email               NVARCHAR(256) NOT NULL,
    PANNumber           NVARCHAR(10) NOT NULL,
    Address             NVARCHAR(500) NULL,
    BusinessName        NVARCHAR(200) NULL,
    ContactPersonName   NVARCHAR(150) NULL,
    GSTNumber           NVARCHAR(15) NULL,
    Username            NVARCHAR(50) NULL,
    PasswordHash        NVARCHAR(500) NULL,
    OriginalPassword    NVARCHAR(100) NULL,
    RoleId              INT NOT NULL,
    UserStatus          NVARCHAR(30) NOT NULL DEFAULT 'PendingApproval',
    ProfileCompleted    BIT NOT NULL DEFAULT 0,
    FailedLoginAttempts INT NOT NULL DEFAULT 0,
    LockoutEnd          DATETIME2 NULL,
    IsActive            BIT NOT NULL DEFAULT 1,
    CreatedBy           BIGINT NULL,
    CreatedDate         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedBy          BIGINT NULL,
    ModifiedDate        DATETIME2 NULL,
    CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT FK_Users_Roles FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId),
    CONSTRAINT UQ_Users_MobileNumber UNIQUE (MobileNumber),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT UQ_Users_PANNumber UNIQUE (PANNumber),
    CONSTRAINT UQ_Users_Username UNIQUE (Username),
    CONSTRAINT CK_Users_UserStatus CHECK (UserStatus IN ('PendingApproval','Approved','Rejected','Active','Deactivated'))
);

CREATE NONCLUSTERED INDEX IX_Users_UserStatus ON dbo.Users(UserStatus);
CREATE NONCLUSTERED INDEX IX_Users_RoleId ON dbo.Users(RoleId);

-- =============================================================================
-- REFRESH TOKENS
-- =============================================================================
IF OBJECT_ID('dbo.RefreshTokens', 'U') IS NOT NULL DROP TABLE dbo.RefreshTokens;
CREATE TABLE dbo.RefreshTokens (
    RefreshTokenId  BIGINT IDENTITY(1,1) NOT NULL,
    UserId          BIGINT NOT NULL,
    Token           NVARCHAR(500) NOT NULL,
    ExpiresAt       DATETIME2 NOT NULL,
    CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    RevokedAt       DATETIME2 NULL,
    ReplacedByToken NVARCHAR(500) NULL,
    CreatedByIp     NVARCHAR(50) NULL,
    CONSTRAINT PK_RefreshTokens PRIMARY KEY CLUSTERED (RefreshTokenId),
    CONSTRAINT FK_RefreshTokens_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId),
    CONSTRAINT UQ_RefreshTokens_Token UNIQUE (Token)
);

CREATE NONCLUSTERED INDEX IX_RefreshTokens_UserId ON dbo.RefreshTokens(UserId);

-- =============================================================================
-- PASSWORD RESET TOKENS
-- =============================================================================
IF OBJECT_ID('dbo.PasswordResetTokens', 'U') IS NOT NULL DROP TABLE dbo.PasswordResetTokens;
CREATE TABLE dbo.PasswordResetTokens (
    TokenId         BIGINT IDENTITY(1,1) NOT NULL,
    UserId          BIGINT NOT NULL,
    Token           NVARCHAR(500) NOT NULL,
    ExpiresAt       DATETIME2 NOT NULL,
    IsUsed          BIT NOT NULL DEFAULT 0,
    CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_PasswordResetTokens PRIMARY KEY CLUSTERED (TokenId),
    CONSTRAINT FK_PasswordResetTokens_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId)
);

-- =============================================================================
-- FILE CATEGORIES
-- =============================================================================
IF OBJECT_ID('dbo.FileCategories', 'U') IS NOT NULL DROP TABLE dbo.FileCategories;
CREATE TABLE dbo.FileCategories (
    CategoryId      INT IDENTITY(1,1) NOT NULL,
    CategoryName    NVARCHAR(100) NOT NULL,
    Description     NVARCHAR(300) NULL,
    IsActive        BIT NOT NULL DEFAULT 1,
    CreatedBy       BIGINT NULL,
    CreatedDate     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedBy      BIGINT NULL,
    ModifiedDate    DATETIME2 NULL,
    CONSTRAINT PK_FileCategories PRIMARY KEY CLUSTERED (CategoryId),
    CONSTRAINT UQ_FileCategories_CategoryName UNIQUE (CategoryName)
);

-- =============================================================================
-- FILE DETAILS
-- =============================================================================
IF OBJECT_ID('dbo.FileDetails', 'U') IS NOT NULL DROP TABLE dbo.FileDetails;
CREATE TABLE dbo.FileDetails (
    FileId              BIGINT IDENTITY(1,1) NOT NULL,
    ClientId            BIGINT NOT NULL,
    CategoryId          INT NOT NULL,
    CategoryName        NVARCHAR(100) NOT NULL,
    FileName            NVARCHAR(255) NOT NULL,
    OriginalFileName    NVARCHAR(255) NOT NULL,
    FilePath            NVARCHAR(500) NOT NULL,
    FileExtension       NVARCHAR(20) NOT NULL,
    FileSize            BIGINT NOT NULL,
    Source              NVARCHAR(50) NOT NULL,
    DocumentStatus      NVARCHAR(30) NOT NULL DEFAULT 'Pending',
    UploadDate          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy           BIGINT NOT NULL,
    CreatedDate         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    IsActive            BIT NOT NULL DEFAULT 1,
    CONSTRAINT PK_FileDetails PRIMARY KEY CLUSTERED (FileId),
    CONSTRAINT FK_FileDetails_Users FOREIGN KEY (ClientId) REFERENCES dbo.Users(UserId),
    CONSTRAINT FK_FileDetails_Categories FOREIGN KEY (CategoryId) REFERENCES dbo.FileCategories(CategoryId),
    CONSTRAINT CK_FileDetails_DocumentStatus CHECK (DocumentStatus IN ('Pending','Approved','Rejected'))
);

CREATE NONCLUSTERED INDEX IX_FileDetails_ClientId ON dbo.FileDetails(ClientId);
CREATE NONCLUSTERED INDEX IX_FileDetails_CategoryId ON dbo.FileDetails(CategoryId);
CREATE NONCLUSTERED INDEX IX_FileDetails_UploadDate ON dbo.FileDetails(UploadDate);
CREATE NONCLUSTERED INDEX IX_FileDetails_OriginalFileName ON dbo.FileDetails(OriginalFileName);

-- =============================================================================
-- AUDIT LOGS
-- =============================================================================
IF OBJECT_ID('dbo.AuditLogs', 'U') IS NOT NULL DROP TABLE dbo.AuditLogs;
CREATE TABLE dbo.AuditLogs (
    AuditLogId      BIGINT IDENTITY(1,1) NOT NULL,
    UserId          BIGINT NULL,
    Action          NVARCHAR(100) NOT NULL,
    EntityName      NVARCHAR(100) NOT NULL,
    EntityId        NVARCHAR(50) NULL,
    OldValues       NVARCHAR(MAX) NULL,
    NewValues       NVARCHAR(MAX) NULL,
    IpAddress       NVARCHAR(50) NULL,
    UserAgent       NVARCHAR(500) NULL,
    CreatedDate     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_AuditLogs PRIMARY KEY CLUSTERED (AuditLogId)
);

CREATE NONCLUSTERED INDEX IX_AuditLogs_UserId ON dbo.AuditLogs(UserId);
CREATE NONCLUSTERED INDEX IX_AuditLogs_CreatedDate ON dbo.AuditLogs(CreatedDate);
CREATE NONCLUSTERED INDEX IX_AuditLogs_EntityName ON dbo.AuditLogs(EntityName);

-- =============================================================================
-- USER APPROVAL HISTORY (Audit for registration workflow)
-- =============================================================================
IF OBJECT_ID('dbo.UserApprovalHistory', 'U') IS NOT NULL DROP TABLE dbo.UserApprovalHistory;
CREATE TABLE dbo.UserApprovalHistory (
    HistoryId       BIGINT IDENTITY(1,1) NOT NULL,
    UserId          BIGINT NOT NULL,
    Action          NVARCHAR(50) NOT NULL,
    Comments        NVARCHAR(500) NULL,
    ActionBy        BIGINT NOT NULL,
    ActionDate      DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_UserApprovalHistory PRIMARY KEY CLUSTERED (HistoryId),
    CONSTRAINT FK_UserApprovalHistory_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId)
);

GO
