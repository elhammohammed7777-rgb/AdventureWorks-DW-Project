-- ============================================================
-- STEP 0: Restore the AdventureWorks2022 SOURCE database
-- Run this ONCE. Not part of the repo's numbered pipeline scripts —
-- this just gets the raw source database onto the instance.
-- ============================================================
RESTORE DATABASE AdventureWorks2022
FROM DISK = 'C:\SQL2025\project_team2\AdventureWorks2022.bak'
WITH MOVE 'AdventureWorks2022' TO 'C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\AdventureWorks2022.mdf',
     MOVE 'AdventureWorks2022_log' TO 'C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\DATA\AdventureWorks2022_log.ldf',
     REPLACE;
GO

-- Sanity check: confirm it restored and is online
SELECT name, state_desc FROM sys.databases WHERE name = 'AdventureWorks2022';
GO


-- ============================================================
-- STEP 1 (00_initialize_database.sql): Create the warehouse database
-- and the bronze / silver / gold schemas.
-- ============================================================
USE master;
GO

IF EXISTS (SELECT * FROM sys.databases WHERE name = 'AdventureWorks_DW')
BEGIN
    ALTER DATABASE AdventureWorks_DW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE AdventureWorks_DW;
END
GO

CREATE DATABASE AdventureWorks_DW;
GO

USE AdventureWorks_DW;
GO

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO


