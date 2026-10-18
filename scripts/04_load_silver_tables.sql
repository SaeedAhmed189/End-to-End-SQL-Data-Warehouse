/* ==============================================================================
   Project     : AdventureWorks Data Warehouse
   Script      : 04_load_silver_tables.sql
   Description : Creates silver.usp_load_silver and runs it. The procedure
                 clears and reloads every Silver table from Bronze.

   Behaviour   :
     - The whole load runs in ONE transaction. If anything fails, Silver is
       rolled back to its previous state (never left half-loaded).
     - Refuses to run if a Bronze table is empty, so a failed bronze load can
       never wipe Silver.
     - Every table's row count and rejected-row count is printed and written
       to etl.load_log.
     - Rows are "rejected" (not loaded) when:
         customer_lookup : customer_key is not a valid integer
         sales_data      : product, customer or territory key has no match
         returns_data    : product or territory key has no match

   Requires    : 03_create_silver_tables.sql has been run.
   ============================================================================== */

USE [AdventureWorks_DW];
GO

CREATE OR ALTER PROCEDURE silver.usp_load_silver
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @batch_id      UNIQUEIDENTIFIER = NEWID(),
            @run_start     DATETIME2        = SYSDATETIME(),
            @start         DATETIME2,
            @current_table NVARCHAR(256)    = N'(start)',
            @rows          BIGINT,
            @src           BIGINT,
            @rej           BIGINT,
            @dups          BIGINT,
            @empty         NVARCHAR(500),
            @msg           NVARCHAR(600),
            @err           NVARCHAR(4000);

    PRINT 'Starting to clear and load Silver Layer...';

    BEGIN TRY
        -- ---------------------------------------------------------------------
        -- 0. PRE-CHECK: never wipe Silver if Bronze is empty
        -- ---------------------------------------------------------------------
        SET @current_table = N'(pre-check)';

        SELECT @empty = STRING_AGG(t.table_name, N', ')
        FROM (VALUES
            (N'bronze.calendar_lookup',              (SELECT COUNT_BIG(*) FROM bronze.calendar_lookup)),
            (N'bronze.territory_lookup',             (SELECT COUNT_BIG(*) FROM bronze.territory_lookup)),
            (N'bronze.customer_lookup',              (SELECT COUNT_BIG(*) FROM bronze.customer_lookup)),
            (N'bronze.product_categories_lookup',    (SELECT COUNT_BIG(*) FROM bronze.product_categories_lookup)),
            (N'bronze.product_subcategories_lookup', (SELECT COUNT_BIG(*) FROM bronze.product_subcategories_lookup)),
            (N'bronze.product_lookup',               (SELECT COUNT_BIG(*) FROM bronze.product_lookup)),
            (N'bronze.returns_data',                 (SELECT COUNT_BIG(*) FROM bronze.returns_data)),
            (N'bronze.sales_data',                   (SELECT COUNT_BIG(*) FROM bronze.sales_data))
        ) AS t(table_name, row_count)
        WHERE t.row_count = 0;

        IF @empty IS NOT NULL
        BEGIN
            SET @msg = CONCAT(N'Bronze table(s) are empty: ', @empty, N'. Run the bronze load first.');
            THROW 50010, @msg, 1;
        END;

        BEGIN TRANSACTION;

        -- ---------------------------------------------------------------------
        -- 1. CLEAR EXISTING DATA (reverse dependency order)
        -- ---------------------------------------------------------------------
        SET @current_table = N'(clearing silver tables)';

        TRUNCATE TABLE silver.sales_data;       -- not referenced by any FK
        TRUNCATE TABLE silver.returns_data;     -- not referenced by any FK

        DELETE FROM silver.product_lookup;      -- referenced by FKs, so DELETE
        DELETE FROM silver.product_subcategories_lookup;
        DELETE FROM silver.product_categories_lookup;
        DELETE FROM silver.customer_lookup;
        DELETE FROM silver.territory_lookup;
        DELETE FROM silver.calendar_lookup;

        PRINT 'Old Silver data cleared (inside transaction).';

        -- ---------------------------------------------------------------------
        -- 2. LOAD (dependency order)
        -- ---------------------------------------------------------------------

        -- A. Calendar Lookup
        --    Weekday logic does not depend on SET DATEFIRST: Monday = 1 ... Sunday = 7
        SET @current_table = N'silver.calendar_lookup';  SET @start = SYSDATETIME();

        INSERT INTO silver.calendar_lookup (
            [date], [year], [quarter], start_of_quarter, month_number, month_name,
            start_of_month, week_day_number, week_day_name, start_of_week)
        SELECT
            [date],
            YEAR([date]),
            DATEPART(QUARTER, [date]),
            CAST(DATEADD(QUARTER, DATEDIFF(QUARTER, 0, [date]), 0) AS DATE),
            MONTH([date]),
            DATENAME(MONTH, [date]),
            CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, [date]), 0) AS DATE),
            ((DATEPART(WEEKDAY, [date]) + @@DATEFIRST - 2) % 7) + 1,
            DATENAME(WEEKDAY, [date]),
            DATEADD(DAY, -((DATEPART(WEEKDAY, [date]) + @@DATEFIRST - 2) % 7), [date])
        FROM bronze.calendar_lookup
        WHERE [date] IS NOT NULL;

        SET @rows = @@ROWCOUNT;
        SELECT @src = COUNT_BIG(*) FROM bronze.calendar_lookup;
        SET @rej = @src - @rows;
        EXEC etl.usp_write_log @batch_id, N'silver', @current_table, @start, N'SUCCESS', @rows, @rej;

        -- B. Territory Lookup
        SET @current_table = N'silver.territory_lookup';  SET @start = SYSDATETIME();

        INSERT INTO silver.territory_lookup (sales_territory_key, region, country, continent)
        SELECT sales_territory_key, region, country, continent
        FROM bronze.territory_lookup;

        SET @rows = @@ROWCOUNT;
        SELECT @src = COUNT_BIG(*) FROM bronze.territory_lookup;
        SET @rej = @src - @rows;
        EXEC etl.usp_write_log @batch_id, N'silver', @current_table, @start, N'SUCCESS', @rows, @rej;

        -- C. Customer Lookup
        SET @current_table = N'silver.customer_lookup';  SET @start = SYSDATETIME();

        INSERT INTO silver.customer_lookup (
            customer_key, full_name, birth_date, marital_status, gender, email_address,
            annual_income, total_children, education_level, occupation, home_owner)
        SELECT
            TRY_CAST(customer_key AS INT),
            -- Proper-case first and last name; trims spaces and tolerates a missing name
            LTRIM(RTRIM(CONCAT(
                UPPER(LEFT(TRIM(first_name), 1)), LOWER(SUBSTRING(TRIM(first_name), 2, 100)),
                N' ',
                UPPER(LEFT(TRIM(last_name), 1)),  LOWER(SUBSTRING(TRIM(last_name), 2, 100))
            ))),
            birth_date,
            CASE WHEN marital_status = 'M' THEN 'Married'
                 WHEN marital_status = 'S' THEN 'Single'
                 ELSE marital_status END,
            CASE WHEN gender = 'M' THEN 'Male'
                 WHEN gender = 'F' THEN 'Female'
                 ELSE gender END,
            email_address,
            annual_income,
            total_children,
            education_level,
            occupation,
            CASE WHEN home_owner = 'Y' THEN 'Yes'
                 WHEN home_owner = 'N' THEN 'No'
                 ELSE home_owner END
        FROM bronze.customer_lookup
        WHERE TRY_CAST(customer_key AS INT) IS NOT NULL;

        SET @rows = @@ROWCOUNT;
        SELECT @src = COUNT_BIG(*) FROM bronze.customer_lookup;
        SET @rej = @src - @rows;
        EXEC etl.usp_write_log @batch_id, N'silver', @current_table, @start, N'SUCCESS', @rows, @rej;

        -- D. Product Categories Lookup
        SET @current_table = N'silver.product_categories_lookup';  SET @start = SYSDATETIME();

        INSERT INTO silver.product_categories_lookup (product_category_key, category_name)
        SELECT product_category_key, category_name
        FROM bronze.product_categories_lookup;

        SET @rows = @@ROWCOUNT;
        SELECT @src = COUNT_BIG(*) FROM bronze.product_categories_lookup;
        SET @rej = @src - @rows;
        EXEC etl.usp_write_log @batch_id, N'silver', @current_table, @start, N'SUCCESS', @rows, @rej;

        -- E. Product Subcategories Lookup
        SET @current_table = N'silver.product_subcategories_lookup';  SET @start = SYSDATETIME();

        INSERT INTO silver.product_subcategories_lookup (product_subcategory_key, subcategory_name, product_category_key)
        SELECT product_subcategory_key, subcategory_name, product_category_key
        FROM bronze.product_subcategories_lookup;

        SET @rows = @@ROWCOUNT;
        SELECT @src = COUNT_BIG(*) FROM bronze.product_subcategories_lookup;
        SET @rej = @src - @rows;
        EXEC etl.usp_write_log @batch_id, N'silver', @current_table, @start, N'SUCCESS', @rows, @rej;

        -- F. Product Lookup (product_size and product_style are dropped by not selecting them)
        SET @current_table = N'silver.product_lookup';  SET @start = SYSDATETIME();

        INSERT INTO silver.product_lookup (
            product_key, product_subcategory_key, product_sku, product_name, model_name,
            product_description, product_color, product_cost, product_price)
        SELECT
            product_key, product_subcategory_key, product_sku, product_name, model_name,
            product_description, product_color,
            CAST(ROUND(product_cost, 2)  AS DECIMAL(10,2)),
            CAST(ROUND(product_price, 2) AS DECIMAL(10,2))
        FROM bronze.product_lookup;

        SET @rows = @@ROWCOUNT;
        SELECT @src = COUNT_BIG(*) FROM bronze.product_lookup;
        SET @rej = @src - @rows;
        EXEC etl.usp_write_log @batch_id, N'silver', @current_table, @start, N'SUCCESS', @rows, @rej;

        -- G. Returns Data (rows with unknown product or territory are rejected)
        SET @current_table = N'silver.returns_data';  SET @start = SYSDATETIME();

        INSERT INTO silver.returns_data (return_date, territory_key, product_key, return_quantity)
        SELECT b.return_date, b.territory_key, b.product_key, b.return_quantity
        FROM bronze.returns_data AS b
        WHERE EXISTS (SELECT 1 FROM silver.product_lookup   AS p WHERE p.product_key         = b.product_key)
          AND EXISTS (SELECT 1 FROM silver.territory_lookup AS t WHERE t.sales_territory_key = b.territory_key);

        SET @rows = @@ROWCOUNT;
        SELECT @src = COUNT_BIG(*) FROM bronze.returns_data;
        SET @rej = @src - @rows;
        EXEC etl.usp_write_log @batch_id, N'silver', @current_table, @start, N'SUCCESS', @rows, @rej;

        -- H. Sales Data (rows with unknown product, customer or territory are rejected)
        SET @current_table = N'silver.sales_data';  SET @start = SYSDATETIME();

        INSERT INTO silver.sales_data (
            order_date, stock_date, order_number, product_key, customer_key,
            territory_key, order_line_item, order_quantity)
        SELECT
            b.order_date, b.stock_date, b.order_number, b.product_key, b.customer_key,
            b.territory_key, b.order_line_item, b.order_quantity
        FROM bronze.sales_data AS b
        WHERE EXISTS (SELECT 1 FROM silver.product_lookup   AS p WHERE p.product_key         = b.product_key)
          AND EXISTS (SELECT 1 FROM silver.customer_lookup  AS c WHERE c.customer_key        = b.customer_key)
          AND EXISTS (SELECT 1 FROM silver.territory_lookup AS t WHERE t.sales_territory_key = b.territory_key);

        SET @rows = @@ROWCOUNT;
        SELECT @src = COUNT_BIG(*) FROM bronze.sales_data;
        SET @rej = @src - @rows;
        EXEC etl.usp_write_log @batch_id, N'silver', @current_table, @start, N'SUCCESS', @rows, @rej;

        -- Duplicate order-line check (warning only)
        SELECT @dups = COUNT_BIG(*) - COUNT_BIG(DISTINCT CONCAT(order_number, N'|', order_line_item))
        FROM silver.sales_data;

        IF @dups > 0
            PRINT CONCAT('WARNING: silver.sales_data has ', FORMAT(@dups, 'N0'),
                         ' duplicate (order_number, order_line_item) rows. Check the source files.');

        COMMIT TRANSACTION;

        PRINT '=====================================================';
        PRINT CONCAT('Silver load completed in ', DATEDIFF(SECOND, @run_start, SYSDATETIME()),
                     ' second(s). Batch id: ', @batch_id);
        PRINT '=====================================================';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @err = LEFT(ERROR_MESSAGE(), 4000);

        -- Written after the rollback so the failure record is kept
        EXEC etl.usp_write_log @batch_id, N'silver', @current_table, @run_start, N'FAILED',
                               NULL, NULL, @err;

        PRINT 'Silver load FAILED and was rolled back. Previous Silver data is unchanged.';
        THROW;
    END CATCH;
END;
GO

-- Run the load
EXEC silver.usp_load_silver;
GO

-- Optional: see what happened in the latest run
-- SELECT * FROM etl.load_log ORDER BY log_id DESC;