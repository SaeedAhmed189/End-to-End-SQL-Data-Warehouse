/* ==============================================================================
   Project: AdventureWorks Data Warehouse
   Description: Create Silver Layer Tables (DDL)
   ============================================================================== */

USE [AdventureWorks_DW];
GO

PRINT 'Starting to build Silver Layer structure...';

-- ==============================================================================
-- 1. DROP EXISTING TABLES (In reverse order of dependencies to avoid FK errors)
-- ==============================================================================
IF OBJECT_ID('silver.sales_data', 'U') IS NOT NULL DROP TABLE silver.sales_data;
IF OBJECT_ID('silver.returns_data', 'U') IS NOT NULL DROP TABLE silver.returns_data;
IF OBJECT_ID('silver.product_lookup', 'U') IS NOT NULL DROP TABLE silver.product_lookup;
IF OBJECT_ID('silver.product_subcategories_lookup', 'U') IS NOT NULL DROP TABLE silver.product_subcategories_lookup;
IF OBJECT_ID('silver.product_categories_lookup', 'U') IS NOT NULL DROP TABLE silver.product_categories_lookup;
IF OBJECT_ID('silver.customer_lookup', 'U') IS NOT NULL DROP TABLE silver.customer_lookup;
IF OBJECT_ID('silver.territory_lookup', 'U') IS NOT NULL DROP TABLE silver.territory_lookup;
IF OBJECT_ID('silver.calendar_lookup', 'U') IS NOT NULL DROP TABLE silver.calendar_lookup;

-- ==============================================================================
-- 2. CREATE DIMENSION (LOOKUP) TABLES
-- ==============================================================================

-- A. Calendar Lookup
CREATE TABLE silver.calendar_lookup (
    [date] DATE PRIMARY KEY,
    [year] INT,
    [quarter] INT,
    start_of_quarter DATE,
    month_number INT,
    month_name NVARCHAR(20),
    start_of_month DATE,
    week_day_number INT,
    week_day_name NVARCHAR(20),
    start_of_week DATE,
    create_date DATETIME2 DEFAULT GETDATE()
);

-- B. Territory Lookup
CREATE TABLE silver.territory_lookup (
    sales_territory_key INT PRIMARY KEY,
    region NVARCHAR(50),
    country NVARCHAR(50),
    continent NVARCHAR(50),
    create_date DATETIME2 DEFAULT GETDATE()
);

-- C. Customer Lookup
CREATE TABLE silver.customer_lookup (
    customer_key INT PRIMARY KEY,
    full_name NVARCHAR(100),
    birth_date DATE,
    marital_status NVARCHAR(10),
    gender NVARCHAR(10),
    email_address NVARCHAR(100),
    annual_income INT,
    total_children TINYINT,
    education_level NVARCHAR(50),
    occupation NVARCHAR(50),
    home_owner NVARCHAR(10),
    create_date DATETIME2 DEFAULT GETDATE()
);

-- D. Product Categories Lookup
CREATE TABLE silver.product_categories_lookup (
    product_category_key INT PRIMARY KEY,
    category_name NVARCHAR(50),
    create_date DATETIME2 DEFAULT GETDATE()
);

-- E. Product Subcategories Lookup
CREATE TABLE silver.product_subcategories_lookup (
    product_subcategory_key INT PRIMARY KEY,
    subcategory_name NVARCHAR(50),
    product_category_key INT,
    create_date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_Silver_SubCat_Category FOREIGN KEY (product_category_key) REFERENCES silver.product_categories_lookup(product_category_key)
);

-- F. Product Lookup
CREATE TABLE silver.product_lookup (
    product_key INT PRIMARY KEY,
    product_subcategory_key INT,
    product_sku NVARCHAR(50),
    product_name NVARCHAR(100),
    model_name NVARCHAR(100),
    product_description NVARCHAR(MAX),
    product_color NVARCHAR(50),
    product_cost DECIMAL(10,2),
    product_price DECIMAL(10,2),
    create_date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_Silver_Product_SubCat FOREIGN KEY (product_subcategory_key) REFERENCES silver.product_subcategories_lookup(product_subcategory_key)
);

-- ==============================================================================
-- 3. CREATE FACT (DATA) TABLES
-- ==============================================================================

-- G. Returns Data
CREATE TABLE silver.returns_data (
    return_date DATE,
    territory_key INT,
    product_key INT,
    return_quantity INT,
    create_date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_Silver_Returns_Territory FOREIGN KEY (territory_key) REFERENCES silver.territory_lookup(sales_territory_key),
    CONSTRAINT FK_Silver_Returns_Product FOREIGN KEY (product_key) REFERENCES silver.product_lookup(product_key)
);

-- H. Sales Data
CREATE TABLE silver.sales_data (
    order_date DATE,
    stock_date DATE,
    order_number NVARCHAR(50),
    product_key INT,
    customer_key INT,
    territory_key INT,
    order_line_item INT,
    order_quantity INT,
    create_date DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT FK_Silver_Sales_Product FOREIGN KEY (product_key) REFERENCES silver.product_lookup(product_key),
    CONSTRAINT FK_Silver_Sales_Customer FOREIGN KEY (customer_key) REFERENCES silver.customer_lookup(customer_key),
    CONSTRAINT FK_Silver_Sales_Territory FOREIGN KEY (territory_key) REFERENCES silver.territory_lookup(sales_territory_key)
);

PRINT 'SUCCESS: Silver Layer structure created!';
GO