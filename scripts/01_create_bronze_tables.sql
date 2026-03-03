/* ==============================================================================
   Project: AdventureWorks Data Warehouse
   Description: Create tables for the Bronze Layer (Raw Ingestion)
   ============================================================================== */

USE [AdventureWorks_DW];
GO

-- =======================================================
-- 1. bronze.calendar_lookup
-- =======================================================
IF OBJECT_ID('bronze.calendar_lookup', 'U') IS NOT NULL 
    DROP TABLE bronze.calendar_lookup;

CREATE TABLE bronze.calendar_lookup (
    [date] DATE NULL
);
PRINT 'SUCCESS: Table [bronze].[calendar_lookup] created.';
GO

-- =======================================================
-- 2. bronze.customer_lookup
-- =======================================================
IF OBJECT_ID('bronze.customer_lookup', 'U') IS NOT NULL 
    DROP TABLE bronze.customer_lookup;

CREATE TABLE bronze.customer_lookup (
    customer_key NVARCHAR(50) NULL, --Has different data type
    prefix NVARCHAR(10) NULL,
    first_name NVARCHAR(50) NULL,
    last_name NVARCHAR(50) NULL,
    birth_date DATE NULL,
    marital_status NVARCHAR(10) NULL,
    gender NVARCHAR(10) NULL,
    email_address NVARCHAR(100) NULL,
    annual_income INT NULL,
    total_children INT NULL,
    education_level NVARCHAR(50) NULL,
    occupation NVARCHAR(50) NULL,
    home_owner NVARCHAR(10) NULL
);
PRINT 'SUCCESS: Table [bronze].[customer_lookup] created.';
GO

-- =======================================================
-- 3. bronze.product_categories_lookup
-- =======================================================
IF OBJECT_ID('bronze.product_categories_lookup', 'U') IS NOT NULL 
    DROP TABLE bronze.product_categories_lookup;

CREATE TABLE bronze.product_categories_lookup (
    product_category_key INT NULL,
    category_name NVARCHAR(50) NULL
);
PRINT 'SUCCESS: Table [bronze].[product_categories_lookup] created.';
GO

-- =======================================================
-- 4. bronze.product_lookup
-- =======================================================
IF OBJECT_ID('bronze.product_lookup', 'U') IS NOT NULL 
    DROP TABLE bronze.product_lookup;

CREATE TABLE bronze.product_lookup (
    product_key INT NULL,
    product_subcategory_key INT NULL,
    product_sku NVARCHAR(50) NULL,
    product_name NVARCHAR(100) NULL,
    model_name NVARCHAR(100) NULL,
    product_description NVARCHAR(MAX) NULL,
    product_color NVARCHAR(50) NULL,
    product_size NVARCHAR(50) NULL,
    product_style NVARCHAR(50) NULL,
    product_cost FLOAT NULL,
    product_price FLOAT NULL
);
PRINT 'SUCCESS: Table [bronze].[product_lookup] created.';
GO

-- =======================================================
-- 5. bronze.product_subcategories_lookup
-- =======================================================
IF OBJECT_ID('bronze.product_subcategories_lookup', 'U') IS NOT NULL 
    DROP TABLE bronze.product_subcategories_lookup;

CREATE TABLE bronze.product_subcategories_lookup (
    product_subcategory_key INT NULL,
    subcategory_name NVARCHAR(50) NULL,
    product_category_key INT NULL
);
PRINT 'SUCCESS: Table [bronze].[product_subcategories_lookup] created.';
GO

-- =======================================================
-- 6. bronze.returns_data
-- =======================================================
IF OBJECT_ID('bronze.returns_data', 'U') IS NOT NULL 
    DROP TABLE bronze.returns_data;

CREATE TABLE bronze.returns_data (
    return_date DATE NULL,
    territory_key INT NULL,
    product_key INT NULL,
    return_quantity INT NULL
);
PRINT 'SUCCESS: Table [bronze].[returns_data] created.';
GO

-- =======================================================
-- 7. bronze.sales_data (Combined 2020, 2021, 2022)
-- =======================================================
IF OBJECT_ID('bronze.sales_data', 'U') IS NOT NULL 
    DROP TABLE bronze.sales_data;

CREATE TABLE bronze.sales_data (
    order_date DATE NULL,
    stock_date DATE NULL,
    order_number NVARCHAR(50) NULL,
    product_key INT NULL,
    customer_key INT NULL,
    territory_key INT NULL,
    order_line_item INT NULL,
    order_quantity INT NULL
);
PRINT 'SUCCESS: Table [bronze].[sales_data] created.';
GO

-- =======================================================
-- 8. bronze.territory_lookup
-- =======================================================
IF OBJECT_ID('bronze.territory_lookup', 'U') IS NOT NULL 
    DROP TABLE bronze.territory_lookup;

CREATE TABLE bronze.territory_lookup (
    sales_territory_key INT NULL,
    region NVARCHAR(50) NULL,
    country NVARCHAR(50) NULL,
    continent NVARCHAR(50) NULL
);
PRINT 'SUCCESS: Table [bronze].[territory_lookup] created.';
GO