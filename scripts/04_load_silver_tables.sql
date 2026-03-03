/* ==============================================================================
   Project: AdventureWorks Data Warehouse
   Description: Clear and Load Silver Layer Tables (DML)
   ============================================================================== */

USE [AdventureWorks_DW];
GO

-- Set Monday as the first day of the week 
SET DATEFIRST 1; 
GO

PRINT 'Starting to clear and load Silver Layer...';

-- ==============================================================================
-- 1. CLEAR EXISTING DATA (Reverse Dependency Order)
-- ==============================================================================
-- Use TRUNCATE for tables without foreign keys pointing to them
TRUNCATE TABLE silver.sales_data;
TRUNCATE TABLE silver.returns_data;

-- Use DELETE for dimension tables (TRUNCATE is not allowed when referenced by FKs)
DELETE FROM silver.product_lookup;
DELETE FROM silver.product_subcategories_lookup;
DELETE FROM silver.product_categories_lookup;
DELETE FROM silver.customer_lookup;
DELETE FROM silver.territory_lookup;
DELETE FROM silver.calendar_lookup;

PRINT 'SUCCESS: Old data cleared.';

-- ==============================================================================
-- 2. TRANSFORM AND LOAD DATA (Dependency Order)
-- ==============================================================================

-- A. Calendar Lookup
INSERT INTO silver.calendar_lookup (
    [date],
    [year],
    [quarter],
    start_of_quarter,
    month_number,
    month_name,
    start_of_month,
    week_day_number,
    week_day_name,
    start_of_week
)
SELECT 
    [date],
    YEAR([date]) AS [year],
    DATEPART(QUARTER, [date]) AS [quarter],
    DATEADD(QUARTER, DATEDIFF(QUARTER, 0, [date]), 0) AS start_of_quarter,
    MONTH([date]) AS month_number,
    DATENAME(MONTH, [date]) AS month_name,
    DATEADD(MONTH, DATEDIFF(MONTH, 0, [date]), 0) AS start_of_month,
    DATEPART(WEEKDAY, [date]) AS week_day_number, 
    DATENAME(WEEKDAY, [date]) AS week_day_name,
	DATEADD(DAY, 1 - DATEPART(WEEKDAY, [date]), [date]) AS start_of_week
FROM bronze.calendar_lookup;
PRINT 'SUCCESS: Loaded silver.calendar_lookup';

-- B. Territory Lookup
INSERT INTO silver.territory_lookup (
    sales_territory_key,
    region,
    country,
    continent
)
SELECT 
    sales_territory_key, 
    region, 
    country, 
    continent
FROM bronze.territory_lookup;
PRINT 'SUCCESS: Loaded silver.territory_lookup';

-- C. Customer Lookup
INSERT INTO silver.customer_lookup (
    customer_key,
    full_name,
    birth_date,
    marital_status,
    gender,
    email_address,
    annual_income,
    total_children,
    education_level,
    occupation,
    home_owner
)
SELECT 
    customer_key,
    -- Concatenate and capitalize first letter of First and Last name
    CONCAT(
        UPPER(LEFT(first_name, 1)), LOWER(SUBSTRING(first_name, 2, LEN(first_name))),
        ' ', 
        UPPER(LEFT(last_name, 1)), LOWER(SUBSTRING(last_name, 2, LEN(last_name)))
    ) AS full_name,
    birth_date,
    -- Map Marital Status
    CASE WHEN marital_status = 'M' THEN 'Married' 
         WHEN marital_status = 'S' THEN 'Single' 
         ELSE marital_status END AS marital_status,
    -- Map Gender
    CASE WHEN gender = 'M' THEN 'Male' 
         WHEN gender = 'F' THEN 'Female' 
         ELSE gender END AS gender,
    email_address,
    annual_income,
    total_children,
    education_level,
    occupation,
    -- Map Home Owner
    CASE WHEN home_owner = 'Y' THEN 'Yes' 
         WHEN home_owner = 'N' THEN 'No' 
         ELSE home_owner END AS home_owner
FROM bronze.customer_lookup
WHERE TRY_CAST(customer_key AS INT) IS NOT NULL;
PRINT 'SUCCESS: Loaded silver.customer_lookup';

-- D. Product Categories Lookup
INSERT INTO silver.product_categories_lookup (
    product_category_key,
    category_name
)
SELECT 
    product_category_key,
    category_name
FROM bronze.product_categories_lookup;
PRINT 'SUCCESS: Loaded silver.product_categories_lookup';

-- E. Product Subcategories Lookup
INSERT INTO silver.product_subcategories_lookup (
    product_subcategory_key,
    subcategory_name,
    product_category_key
)
SELECT 
    product_subcategory_key, 
    subcategory_name, 
    product_category_key
FROM bronze.product_subcategories_lookup;
PRINT 'SUCCESS: Loaded silver.product_subcategories_lookup';

-- F. Product Lookup
INSERT INTO silver.product_lookup (
    product_key,
    product_subcategory_key,
    product_sku,
    product_name,
    model_name,
    product_description,
    product_color,
    product_cost,
    product_price
)
SELECT 
    product_key,
    product_subcategory_key,
    product_sku,
    product_name,
    model_name,
    product_description,
    product_color,
    -- Rounding to 2 decimal places and casting
    CAST(ROUND(product_cost, 2) AS DECIMAL(10,2)) AS product_cost,
    CAST(ROUND(product_price, 2) AS DECIMAL(10,2)) AS product_price
    -- product_size and product_style columns are dropped simply by not selecting them
FROM bronze.product_lookup;
PRINT 'SUCCESS: Loaded silver.product_lookup';

-- G. Returns Data
INSERT INTO silver.returns_data (
    return_date,
    territory_key,
    product_key,
    return_quantity
)
SELECT 
    return_date, 
    territory_key, 
    product_key, 
    return_quantity
FROM bronze.returns_data;
PRINT 'SUCCESS: Loaded silver.returns_data';

-- H. Sales Data
INSERT INTO silver.sales_data (
    order_date,
    stock_date,
    order_number,
    product_key,
    customer_key,
    territory_key,
    order_line_item,
    order_quantity
)
SELECT 
    order_date,
    stock_date,
    order_number,
    product_key,
    customer_key,
    territory_key,
    order_line_item,
    order_quantity
FROM bronze.sales_data;
PRINT 'SUCCESS: Loaded silver.sales_data';

PRINT 'Silver Layer Data Loaded Successfully!';
GO