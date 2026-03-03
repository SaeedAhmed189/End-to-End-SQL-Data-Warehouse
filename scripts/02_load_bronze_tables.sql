/* ==============================================================================
   Project: AdventureWorks Data Warehouse
   Description: Dynamic script to Truncate and BULK INSERT CSV files into Bronze Layer
   ============================================================================== */

USE [AdventureWorks_DW];
GO

-- Define the base path for the files
DECLARE @base_path NVARCHAR(500) = 'E:\End-to-End-SQL-Data-Warehouse\datasets';
DECLARE @sql NVARCHAR(MAX);

PRINT 'Starting Data Ingestion into Bronze Layer...';

-- =======================================================
-- 1. bronze.calendar_lookup
-- =======================================================
TRUNCATE TABLE bronze.calendar_lookup;
SET @sql = 'BULK INSERT bronze.calendar_lookup FROM ''' + @base_path + 'AdventureWorks Calendar Lookup.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Truncated and Loaded bronze.calendar_lookup';

-- =======================================================
-- 2. bronze.customer_lookup
-- =======================================================
TRUNCATE TABLE bronze.customer_lookup;
SET @sql = 'BULK INSERT bronze.customer_lookup FROM ''' + @base_path + 'AdventureWorks Customer Lookup.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Truncated and Loaded bronze.customer_lookup';

-- =======================================================
-- 3. bronze.product_categories_lookup
-- =======================================================
TRUNCATE TABLE bronze.product_categories_lookup;
SET @sql = 'BULK INSERT bronze.product_categories_lookup FROM ''' + @base_path + 'AdventureWorks Product Categories Lookup.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Truncated and Loaded bronze.product_categories_lookup';

-- =======================================================
-- 4. bronze.product_lookup
-- =======================================================
TRUNCATE TABLE bronze.product_lookup;
SET @sql = 'BULK INSERT bronze.product_lookup FROM ''' + @base_path + 'AdventureWorks Product Lookup.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Truncated and Loaded bronze.product_lookup';

-- =======================================================
-- 5. bronze.product_subcategories_lookup
-- =======================================================
TRUNCATE TABLE bronze.product_subcategories_lookup;
SET @sql = 'BULK INSERT bronze.product_subcategories_lookup FROM ''' + @base_path + 'AdventureWorks Product Subcategories Lookup.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Truncated and Loaded bronze.product_subcategories_lookup';

-- =======================================================
-- 6. bronze.returns_data
-- =======================================================
TRUNCATE TABLE bronze.returns_data;
SET @sql = 'BULK INSERT bronze.returns_data FROM ''' + @base_path + 'AdventureWorks Returns Data.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Truncated and Loaded bronze.returns_data';

-- =======================================================
-- 7. bronze.territory_lookup
-- =======================================================
TRUNCATE TABLE bronze.territory_lookup;
SET @sql = 'BULK INSERT bronze.territory_lookup FROM ''' + @base_path + 'AdventureWorks Territory Lookup.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Truncated and Loaded bronze.territory_lookup';

-- =======================================================
-- 8. bronze.sales_data (Combining 2020, 2021, 2022)
-- =======================================================
-- Truncate the table only once before loading all three files
TRUNCATE TABLE bronze.sales_data;

SET @sql = 'BULK INSERT bronze.sales_data FROM ''' + @base_path + 'AdventureWorks Sales Data 2020.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Loaded bronze.sales_data (2020)';

SET @sql = 'BULK INSERT bronze.sales_data FROM ''' + @base_path + 'AdventureWorks Sales Data 2021.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Loaded bronze.sales_data (2021)';

SET @sql = 'BULK INSERT bronze.sales_data FROM ''' + @base_path + 'AdventureWorks Sales Data 2022.csv'' WITH (FIRSTROW = 2, FORMAT = ''CSV'', FIELDQUOTE = ''"'', ROWTERMINATOR = ''\n'', TABLOCK);';
EXEC(@sql);
PRINT 'SUCCESS: Loaded bronze.sales_data (2022)';

PRINT 'Data Ingestion Completed Successfully!';
GO