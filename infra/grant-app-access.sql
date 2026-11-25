-- Azure SQL maps service principals and managed identities by application/client ID.
-- Run in MtbBikeShop as its configured Entra administrator.
DECLARE @clientId uniqueidentifier = '$(IdentityClientId)';
DECLARE @sid binary(16) = CONVERT(binary(16), @clientId);
DECLARE @existingSid varbinary(85) = (
    SELECT sid FROM sys.database_principals WHERE name = N'mtbbikeshop'
);

IF @existingSid IS NOT NULL AND @existingSid <> @sid
BEGIN
    IF EXISTS (
        SELECT 1 FROM sys.schemas
        WHERE principal_id = USER_ID(N'mtbbikeshop')
    ) OR EXISTS (
        SELECT 1 FROM sys.objects
        WHERE principal_id = USER_ID(N'mtbbikeshop')
    )
        THROW 50001, 'mtbbikeshop owns database objects. Review ownership before changing its SID.', 1;

    DROP USER [mtbbikeshop];
    SET @existingSid = NULL;
END;

IF @existingSid IS NULL
BEGIN
    DECLARE @createUser nvarchar(max) =
        N'CREATE USER [mtbbikeshop] WITH SID = '
        + CONVERT(nvarchar(34), @sid, 1)
        + N', TYPE = E;';
    EXEC sys.sp_executesql @createUser;
END;

GRANT CONNECT TO [mtbbikeshop];
IF IS_ROLEMEMBER(N'db_datareader', N'mtbbikeshop') <> 1
    ALTER ROLE db_datareader ADD MEMBER [mtbbikeshop];
IF IS_ROLEMEMBER(N'db_datawriter', N'mtbbikeshop') <> 1
    ALTER ROLE db_datawriter ADD MEMBER [mtbbikeshop];

-- EnsureCreated runs at app startup. Remove this role after moving DDL to a migration job.
IF IS_ROLEMEMBER(N'db_ddladmin', N'mtbbikeshop') <> 1
    ALTER ROLE db_ddladmin ADD MEMBER [mtbbikeshop];
