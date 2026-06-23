-- OTP-based forgot password flow (extends Users / PasswordResetTokens pattern)

USE DMS_DB;

GO



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

