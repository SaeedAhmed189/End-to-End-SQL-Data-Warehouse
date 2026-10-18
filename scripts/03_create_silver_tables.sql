/* ==============================================================================
   Project     : AdventureWorks Data Warehouse
   Script      : 03_create_silver_tables.sql
   Description : Creates (1) the ETL load log and its logging helper and
                 (2) the Silver layer tables, keys and indexes.

   Note        : The ETL log is created only if it does not exist, so running
                 this script again keeps your load history. Silver tables are
                 dropped and recreated (they are empty until 04 is run).
   ============================================================================== */

USE [AdventureWorks_DW];
GO

PRINT 'Starting to build ETL helpers and Silver Layer structure...';
GO

-- ==============================================================================
-- 1. ETL SCHEMA, LOAD LOG AND LOGGING HELPER
-- ==============================================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'etl')
    EXEC(N'CREATE SCHEMA [etl]');
GO

IF OBJECT_ID(N'etl.load_log', N'U') IS NULL
BEGIN
    CREATE TABLE etl.load_log (
        log_id         INT IDENTITY(1,1) CONSTRAINT PK_etl_load_log PRIMARY KEY,
        batch_id       UNIQUEIDENTIFIER NOT NULL,   -- groups all rows of one run
        layer          NVARCHAR(20)     NOT NULL,   -- bronze / silver / gold
        table_name     NVARCHAR(256)    NOT NULL,
        start_time     DATETIME2        NOT NULL,
        end_time       DATETIME2        NOT NULL,
        rows_loaded    BIGINT           NULL,
        rows_rejected  BIGINT           NULL,       -- source rows not loaded
        status         NVARCHAR(20)     NOT NULL,   -- SUCCESS / FAILED
        error_message  NVARCHAR(4000)   NULL
    );
END
GO

CREATE OR ALTER PROCEDURE etl.usp_write_log
    @batch_id      UNIQUEIDENTIFIER,
    @layer         NVARCHAR(20),
    @table_name    NVARCHAR(256),
    @start_time    DATETIME2,
    @status        NVARCHAR(20),
    @rows_loaded   BIGINT        = NULL,
    @rows_rejected BIGINT        = NULL,
    @error_message NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO etl.load_log
        (batch_id, layer, table_name, start_time, end_time,
         rows_loaded, rows_rejected, status, error_message)
    VALUES
        (@batch_id, @layer, @table_name, @start_time, SYSDATETIME(),
         @rows_loaded, @rows_rejected, @status, @error_message);

    IF @status = N'SUCCESS'
    BEGIN
        PRINT CONCAT('SUCCESS: ', @table_name, ' - ', FORMAT(@rows_loaded, 'N0'), ' rows loaded',
                     IIF(@rows_rejected > 0, CONCAT(' (', FORMAT(@rows_rejected, 'N0'), ' rejected)'), ''));
    END
    ELSE
    BEGIN
        PRINT CONCAT('FAILED : ', @table_name, ' - ', @error_message);
    END
END
GO

-- ==============================================================================
-- 2. DROP EXISTING SILVER TABLES (reverse dependency order)
-- ==============================================================================
IF OBJECT_ID('silver.sales_data', 'U') IS NOT NULL DROP TABLE silver.sales_data;
IF OBJECT_ID('silver.returns_data', 'U') IS NOT NULL DROP TABLE silver.returns_data;
IF OBJECT_ID('silver.product_lookup', 'U') IS NOT NULL DROP TABLE silver.product_lookup;
IF OBJECT_ID('silver.product_subcategories_lookup', 'U') IS NOT NULL DROP TABLE silver.product_subcategories_lookup;
IF OBJECT_ID('silver.product_categories_lookup', 'U') IS NOT NULL DROP TABLE silver.product_categories_lookup;
IF OBJECT_ID('silver.customer_lookup', 'U') IS NOT NULL DROP TABLE silver.customer_lookup;
IF OBJECT_ID('silver.territory_lookup', 'U') IS NOT NULL DROP TABLE silver.territory_lookup;
IF OBJECT_ID('silver.calendar_lookup', 'U') IS NOT NULL DROP TABLE silver.calendar_lookup;
GO

-- ==============================================================================
-- 3. DIMENSION (LOOKUP) TABLES
-- ==============================================================================

-- A. Calendar Lookup
CREATE TABLE silver.calendar_lookup (
    [date]            DATE         NOT NULL CONSTRAINT PK_silver_calendar PRIMARY KEY,
    [year]            INT          NOT NULL,
    [quarter]         INT          NOT NULL,
    start_of_quarter  DATE         NOT NULL,
    month_number      INT          NOT NULL,
    month_name        NVARCHAR(20) NOT NULL,
    start_of_month    DATE         NOT NULL,
    week_day_number   INT          NOT NULL,   -- 1 = Monday ... 7 = Sunday
    week_day_name     NVARCHAR(20) NOT NULL,
    start_of_week     DATE         NOT NULL,   -- the Monday of that week
    create_date       DATETIME2    NOT NULL CONSTRAINT DF_silver_calendar_cd DEFAULT SYSDATETIME()
);

-- B. Territory Lookup
CREATE TABLE silver.territory_lookup (
    sales_territory_key INT NOT NULL CONSTRAINT PK_silver_territory PRIMARY KEY,
    region      NVARCHAR(50),
    country     NVARCHAR(50),
    continent   NVARCHAR(50),
    create_date DATETIME2 NOT NULL CONSTRAINT DF_silver_territory_cd DEFAULT SYSDATETIME()
);

-- C. Customer Lookup
CREATE TABLE silver.customer_lookup (
    customer_key    INT NOT NULL CONSTRAINT PK_silver_customer PRIMARY KEY,
    full_name       NVARCHAR(100),
    birth_date      DATE,
    marital_status  NVARCHAR(10),
    gender          NVARCHAR(10),
    email_address   NVARCHAR(100),
    annual_income   INT,
    total_children  TINYINT,
    education_level NVARCHAR(50),
    occupation      NVARCHAR(50),
    home_owner      NVARCHAR(10),
    create_date     DATETIME2 NOT NULL CONSTRAINT DF_silver_customer_cd DEFAULT SYSDATETIME()
);

-- D. Product Categories Lookup
CREATE TABLE silver.product_categories_lookup (
    product_category_key INT NOT NULL CONSTRAINT PK_silver_prod_cat PRIMARY KEY,
    category_name NVARCHAR(50),
    create_date   DATETIME2 NOT NULL CONSTRAINT DF_silver_prod_cat_cd DEFAULT SYSDATETIME()
);

-- E. Product Subcategories Lookup
CREATE TABLE silver.product_subcategories_lookup (
    product_subcategory_key INT NOT NULL CONSTRAINT PK_silver_prod_subcat PRIMARY KEY,
    subcategory_name     NVARCHAR(50),
    product_category_key INT,
    create_date          DATETIME2 NOT NULL CONSTRAINT DF_silver_prod_subcat_cd DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Silver_SubCat_Category
        FOREIGN KEY (product_category_key) REFERENCES silver.product_categories_lookup(product_category_key)
);
CREATE INDEX IX_silver_subcat_category ON silver.product_subcategories_lookup (product_category_key);

-- F. Product Lookup
CREATE TABLE silver.product_lookup (
    product_key             INT NOT NULL CONSTRAINT PK_silver_product PRIMARY KEY,
    product_subcategory_key INT,
    product_sku             NVARCHAR(50),
    product_name            NVARCHAR(100),
    model_name              NVARCHAR(100),
    product_description     NVARCHAR(MAX),
    product_color           NVARCHAR(50),
    product_cost            DECIMAL(10,2),
    product_price           DECIMAL(10,2),
    create_date             DATETIME2 NOT NULL CONSTRAINT DF_silver_product_cd DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Silver_Product_SubCat
        FOREIGN KEY (product_subcategory_key) REFERENCES silver.product_subcategories_lookup(product_subcategory_key)
);
CREATE INDEX IX_silver_product_subcat ON silver.product_lookup (product_subcategory_key);

-- ==============================================================================
-- 4. FACT (DATA) TABLES
-- ==============================================================================

-- G. Returns Data
CREATE TABLE silver.returns_data (
    return_date     DATE,
    territory_key   INT,
    product_key     INT,
    return_quantity INT,
    create_date     DATETIME2 NOT NULL CONSTRAINT DF_silver_returns_cd DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Silver_Returns_Territory FOREIGN KEY (territory_key) REFERENCES silver.territory_lookup(sales_territory_key),
    CONSTRAINT FK_Silver_Returns_Product   FOREIGN KEY (product_key)   REFERENCES silver.product_lookup(product_key)
);
CREATE INDEX IX_silver_returns_product   ON silver.returns_data (product_key);
CREATE INDEX IX_silver_returns_territory ON silver.returns_data (territory_key);

-- H. Sales Data
CREATE TABLE silver.sales_data (
    order_date      DATE,
    stock_date      DATE,
    order_number    NVARCHAR(50),
    product_key     INT,
    customer_key    INT,
    territory_key   INT,
    order_line_item INT,
    order_quantity  INT,
    create_date     DATETIME2 NOT NULL CONSTRAINT DF_silver_sales_cd DEFAULT SYSDATETIME(),
    CONSTRAINT FK_Silver_Sales_Product   FOREIGN KEY (product_key)   REFERENCES silver.product_lookup(product_key),
    CONSTRAINT FK_Silver_Sales_Customer  FOREIGN KEY (customer_key)  REFERENCES silver.customer_lookup(customer_key),
    CONSTRAINT FK_Silver_Sales_Territory FOREIGN KEY (territory_key) REFERENCES silver.territory_lookup(sales_territory_key)
);
CREATE CLUSTERED INDEX CIX_silver_sales_order_date ON silver.sales_data (order_date);
CREATE INDEX IX_silver_sales_product   ON silver.sales_data (product_key);
CREATE INDEX IX_silver_sales_customer  ON silver.sales_data (customer_key);
CREATE INDEX IX_silver_sales_territory ON silver.sales_data (territory_key);

/* OPTIONAL - once the duplicate check in 04 reports 0 duplicates, you can
   enforce uniqueness of an order line so a CSV loaded twice is rejected:

   ALTER TABLE silver.sales_data ALTER COLUMN order_number    NVARCHAR(50) NOT NULL;
   ALTER TABLE silver.sales_data ALTER COLUMN order_line_item INT          NOT NULL;
   ALTER TABLE silver.sales_data ADD CONSTRAINT UQ_silver_sales_line
       UNIQUE (order_number, order_line_item);
*/

PRINT 'SUCCESS: ETL helpers and Silver Layer structure created!';
GO