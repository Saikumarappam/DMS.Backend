-- =============================================================================
-- Fix admin password hash (seed used a placeholder BCrypt string that never
-- verified against Admin@123). Run on existing databases after 09/10 migrations.
-- =============================================================================

SET NOCOUNT ON;

UPDATE dbo.Users
SET PasswordHash = '$2a$11$NBJ9B9Ze9KgfOzIglcyDsOytSH70RdVSgSbLonuqRVejLeGejklqa',
    OriginalPassword = 'Admin@123'
WHERE Username = 'admin';

IF @@ROWCOUNT = 0
    PRINT 'No admin user found — nothing updated.';
ELSE
    PRINT 'Admin PasswordHash updated. Login with username admin / password Admin@123.';

GO
