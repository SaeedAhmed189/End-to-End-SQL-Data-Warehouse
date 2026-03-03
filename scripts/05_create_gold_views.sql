/* ==============================================================================
   Project: AdventureWorks Data Warehouse
   Script: Create Gold Layer Views (Reporting Layer) - Row Number Surrogate Keys
   ============================================================================== */

USE [AdventureWorks_DW];
GO

PRINT 'Starting to build Gold Layer views...';
GO

-- ==============================================================================
-- 1. DROP EXISTING VIEWS
-- ==============================================================================
IF OBJECT_ID('gold.dim_calendar', 'V') IS NOT NULL DROP VIEW gold.dim_calendar;
IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL DROP VIEW gold.dim_customers;
IF OBJECT_ID('gold.dim_territory', 'V') IS NOT NULL DROP VIEW gold.dim_territory;
IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL DROP VIEW gold.dim_products;
IF OBJECT_ID('gold.fact_returns', 'V') IS NOT NULL DROP VIEW gold.fact_returns;
IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL DROP VIEW gold.fact_sales;
GO

PRINT 'SUCCESS: Existing Gold views dropped.';
GO

-- ==============================================================================
-- 2. CREATE DIMENSION VIEWS (Generating Surrogate Keys via ROW_NUMBER)
-- ==============================================================================

-- A. Calendar Dimension
CREATE VIEW gold.dim_calendar AS
SELECT 
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
FROM silver.calendar_lookup;
GO

PRINT 'SUCCESS: View gold.dim_calendar created.';
GO

-- B. Customer Dimension (With ROW_NUMBER Surrogate Key)
CREATE VIEW gold.dim_customers AS
SELECT 
    -- Generate new Surrogate Key
    ROW_NUMBER() OVER (ORDER BY customer_key) AS customer_key, 
    -- Rename source key to ID
    customer_key AS customer_id,       
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
FROM silver.customer_lookup;
GO

PRINT 'SUCCESS: View gold.dim_customers created.';
GO

-- C. Territory Dimension
CREATE VIEW gold.dim_territory AS
SELECT 
    sales_territory_key,
    region,
    country,
    continent
FROM silver.territory_lookup;
GO

PRINT 'SUCCESS: View gold.dim_territory created.';
GO

-- D. Products Dimension (Denormalized with ROW_NUMBER Surrogate Key)
CREATE VIEW gold.dim_products AS
SELECT 
    -- Generate new Surrogate Key
    ROW_NUMBER() OVER (ORDER BY p.product_key) AS product_key,
    -- Rename source key to ID
    p.product_key AS product_id,       
    p.product_sku,
    p.product_name,
    p.model_name,
    p.product_description,
    p.product_color,
    p.product_cost,
    p.product_price,
    s.subcategory_name,
    c.category_name
FROM silver.product_lookup p
LEFT JOIN silver.product_subcategories_lookup s 
    ON p.product_subcategory_key = s.product_subcategory_key
LEFT JOIN silver.product_categories_lookup c 
    ON s.product_category_key = c.product_category_key;
GO

PRINT 'SUCCESS: View gold.dim_products created.';
GO

-- ==============================================================================
-- 3. CREATE FACT VIEWS (Joining to Gold Dimensions for Surrogate Keys)
-- ==============================================================================

-- E. Returns Fact
CREATE VIEW gold.fact_returns AS
SELECT 
    r.return_date,
    r.territory_key,
    p.product_key,      -- Bringing in generated Surrogate Key from Gold Dim
    r.return_quantity
FROM silver.returns_data r
-- Join Silver Returns to Gold Products using the Natural ID
LEFT JOIN gold.dim_products p 
    ON r.product_key = p.product_id; 
GO

PRINT 'SUCCESS: View gold.fact_returns created.';
GO

-- F. Sales Fact (With Calculated Revenue & Generated Surrogate Keys)
CREATE VIEW gold.fact_sales AS
SELECT 
    s.order_date,
    s.stock_date,
    s.order_number,
    p.product_key,      -- Bringing in generated Surrogate Key from Gold Dim
    c.customer_key,     -- Bringing in generated Surrogate Key from Gold Dim
    s.territory_key,
    s.order_line_item,
    s.order_quantity,
    p.product_price,
    (s.order_quantity * p.product_price) AS sales_amount
FROM silver.sales_data s
-- Join Silver Sales to Gold Dimensions using the Natural IDs
LEFT JOIN gold.dim_products p 
    ON s.product_key = p.product_id
LEFT JOIN gold.dim_customers c 
    ON s.customer_key = c.customer_id;
GO

PRINT 'SUCCESS: View gold.fact_sales created.';
GO

PRINT 'Gold Layer Views Creation Completed Successfully!';
GO