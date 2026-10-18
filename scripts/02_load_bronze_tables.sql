/* ==============================================================================
   Project     : AdventureWorks Data Warehouse
   Script      : Load Bronze Layer
   Description : Truncates and reloads each bronze table from its CSV file(s).

   Behaviour   :
     - Each table is loaded inside its own transaction. If anything fails
       (missing file, bad data, zero rows loaded), that table is rolled back
       and its previous data is preserved.
     - A failure on one table does not stop the other tables from loading.
     - A summary is printed at the end, and the script raises an error if
       any table failed, so a failed run is never reported as a success.

   Requirements: SQL Server 2017+ (FORMAT = 'CSV'). The SQL Server service
                 account must have read access to the base path.
   ============================================================================== */

USE [AdventureWorks_DW];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

-- -------------------------------------------------------------------------
-- Configuration
-- -------------------------------------------------------------------------
DECLARE @base_path NVARCHAR(500) = N'D:\Projects\End-to-End-SQL-Data-Warehouse\datasets';

-- Make sure the path ends with a backslash (the cause of the original error)
IF RIGHT(@base_path, 1) <> N'\'
    SET @base_path += N'\';

-- -------------------------------------------------------------------------
-- Load plan: which CSV goes into which table (a table can have many files)
-- -------------------------------------------------------------------------
DECLARE @files TABLE (
    file_id      INT IDENTITY(1,1) PRIMARY KEY,
    target_table NVARCHAR(256) NOT NULL,
    csv_file     NVARCHAR(260) NOT NULL
);

INSERT INTO @files (target_table, csv_file) VALUES
    (N'bronze.calendar_lookup',            N'AdventureWorks Calendar Lookup.csv'),
    (N'bronze.customer_lookup',            N'AdventureWorks Customer Lookup.csv'),
    (N'bronze.product_categories_lookup',  N'AdventureWorks Product Categories Lookup.csv'),
    (N'bronze.product_lookup',             N'AdventureWorks Product Lookup.csv'),
    (N'bronze.product_subcategories_lookup', N'AdventureWorks Product Subcategories Lookup.csv'),
    (N'bronze.returns_data',               N'AdventureWorks Returns Data.csv'),
    (N'bronze.territory_lookup',           N'AdventureWorks Territory Lookup.csv'),
    (N'bronze.sales_data',                 N'AdventureWorks Sales Data 2020.csv'),
    (N'bronze.sales_data',                 N'AdventureWorks Sales Data 2021.csv'),
    (N'bronze.sales_data',                 N'AdventureWorks Sales Data 2022.csv');

-- One row per target table, in load order
DECLARE @tables TABLE (
    table_id     INT IDENTITY(1,1) PRIMARY KEY,
    target_table NVARCHAR(256) NOT NULL
);

INSERT INTO @tables (target_table)
SELECT target_table
FROM @files
GROUP BY target_table
ORDER BY MIN(file_id);

-- -------------------------------------------------------------------------
-- Working variables
-- -------------------------------------------------------------------------
DECLARE @table_id     INT = 1,
        @table_count  INT = (SELECT COUNT(*) FROM @tables),
        @target       NVARCHAR(256),
        @file_id      INT,
        @csv_file     NVARCHAR(260),
        @full_path    NVARCHAR(800),
        @sql          NVARCHAR(MAX),
        @row_count    BIGINT,
        @ok_count     INT = 0,
        @failed_count INT = 0,
        @start_time   DATETIME2 = SYSDATETIME(),
        @summary      NVARCHAR(200);

PRINT '=====================================================';
PRINT CONCAT('Bronze layer load started at ', CONVERT(VARCHAR(19), @start_time, 120));
PRINT CONCAT('Source folder: ', @base_path);
PRINT '=====================================================';

-- -------------------------------------------------------------------------
-- Main loop: one transaction per target table
-- -------------------------------------------------------------------------
WHILE @table_id <= @table_count
BEGIN
    SELECT @target = target_table FROM @tables WHERE table_id = @table_id;

    BEGIN TRY
        IF OBJECT_ID(@target, N'U') IS NULL
            THROW 50001, 'Target table does not exist.', 1;

        BEGIN TRANSACTION;

        -- Clear the table once, before its first file
        SET @sql = N'TRUNCATE TABLE ' + @target + N';';
        EXEC sys.sp_executesql @sql;

        -- Load every file that belongs to this table
        SELECT @file_id = MIN(file_id) FROM @files WHERE target_table = @target;

        WHILE @file_id IS NOT NULL
        BEGIN
            SELECT @csv_file = csv_file FROM @files WHERE file_id = @file_id;
            SET @full_path = @base_path + @csv_file;

            SET @sql = N'BULK INSERT ' + @target
                     + N' FROM N''' + REPLACE(@full_path, N'''', N'''''') + N''''
                     + N' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'','
                     + N' ROWTERMINATOR = ''\n'', TABLOCK);';
            EXEC sys.sp_executesql @sql;

            PRINT CONCAT('   file loaded: ', @csv_file);

            SELECT @file_id = MIN(file_id)
            FROM @files
            WHERE target_table = @target AND file_id > @file_id;
        END;

        -- Verify that something was actually loaded
        SET @sql = N'SELECT @cnt = COUNT_BIG(*) FROM ' + @target + N';';
        EXEC sys.sp_executesql @sql, N'@cnt BIGINT OUTPUT', @cnt = @row_count OUTPUT;

        IF @row_count = 0
            THROW 50002, 'The load finished but the table has 0 rows.', 1;

        COMMIT TRANSACTION;

        SET @ok_count += 1;
        PRINT CONCAT('SUCCESS: ', @target, ' - ', FORMAT(@row_count, 'N0'), ' rows loaded');
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @failed_count += 1;
        PRINT CONCAT('FAILED : ', @target, ' (rolled back, previous data kept)');
        PRINT CONCAT('         Error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
    END CATCH;

    SET @table_id += 1;
END;

-- -------------------------------------------------------------------------
-- Summary
-- -------------------------------------------------------------------------
PRINT '=====================================================';
PRINT CONCAT('Finished in ', DATEDIFF(SECOND, @start_time, SYSDATETIME()), ' second(s). ',
             'Succeeded: ', @ok_count, ' | Failed: ', @failed_count);
PRINT '=====================================================';

IF @failed_count > 0
BEGIN
    SET @summary = CONCAT('Bronze load completed with ', @failed_count, ' failed table(s). See messages above.');
    THROW 50000, @summary, 1;
END;
GO