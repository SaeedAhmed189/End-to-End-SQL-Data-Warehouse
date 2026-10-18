/* ==============================================================================
   Project     : AdventureWorks Data Warehouse
   Script      : 05_create_gold_views.sql
   Description : Creates the Gold (reporting) layer as a star schema of views.

   Design      :
     - Keys are the stable source keys from Silver (customer_key, product_key,
       territory_key). They never shift when data is reloaded, so saved
       relationships in Power BI or Excel never break.
     - Key names are identical in dimensions and facts, so relationships can be
       created by matching names:
           fact_sales.order_date    -> dim_calendar.date
           fact_sales.product_key   -> dim_products.product_key
           fact_sales.customer_key  -> dim_customers.customer_key
           fact_sales.territory_key -> dim_territory.territory_key
           (the same keys apply to fact_returns)
     - Fact views read from Silver directly (not from other Gold views), so
       there are no chained views to recompute on every query.
     - CREATE OR ALTER keeps permissions and replaces the old versions that
       used ROW_NUMBER() surrogate keys.

   Requires    : 03 and 04 have been run (Silver is loaded).
   ============================================================================== */

USE [AdventureWorks_DW];
GO

PRINT 'Starting to build Gold Layer views...';
GO

-- ==============================================================================
-- 1. DIMENSION VIEWS
-- ==============================================================================

-- A. Calendar Dimension
CREATE OR ALTER VIEW gold.dim_calendar
AS
SELECT
    [date],
    [year],
    [quarter],
    start_of_quarter,
    month_number,
    month_name,
    start_of_month,
    week_day_number,      -- 1 = Monday ... 7 = Sunday
    week_day_name,
    start_of_week
FROM silver.calendar_lookup;
GO

PRINT 'SUCCESS: View gold.dim_calendar created.';
GO

-- B. Customer Dimension
CREATE OR ALTER VIEW gold.dim_customers
AS
SELECT
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
FROM silver.customer_lookup;
GO

PRINT 'SUCCESS: View gold.dim_customers created.';
GO

-- C. Territory Dimension (key renamed so it matches the fact tables)
CREATE OR ALTER VIEW gold.dim_territory
AS
SELECT
    sales_territory_key AS territory_key,
    region,
    country,
    continent
FROM silver.territory_lookup;
GO

PRINT 'SUCCESS: View gold.dim_territory created.';
GO

-- D. Product Dimension (denormalised: product + subcategory + category)
CREATE OR ALTER VIEW gold.dim_products
AS
SELECT
    p.product_key,
    p.product_sku,
    p.product_name,
    p.model_name,
    p.product_description,
    p.product_color,
    p.product_cost,
    p.product_price,
    s.subcategory_name,
    c.category_name
FROM silver.product_lookup AS p
LEFT JOIN silver.product_subcategories_lookup AS s
    ON p.product_subcategory_key = s.product_subcategory_key
LEFT JOIN silver.product_categories_lookup AS c
    ON s.product_category_key = c.product_category_key;
GO

PRINT 'SUCCESS: View gold.dim_products created.';
GO

-- ==============================================================================
-- 2. FACT VIEWS
-- ==============================================================================

-- E. Returns Fact
CREATE OR ALTER VIEW gold.fact_returns
AS
SELECT
    r.return_date,
    r.territory_key,
    r.product_key,
    r.return_quantity
FROM silver.returns_data AS r;
GO

PRINT 'SUCCESS: View gold.fact_returns created.';
GO

-- F. Sales Fact (with unit price/cost and calculated amounts)
--    INNER JOIN is safe: Silver foreign keys guarantee every sale has a product.
CREATE OR ALTER VIEW gold.fact_sales
AS
SELECT
    s.order_date,
    s.stock_date,
    s.order_number,
    s.order_line_item,
    s.product_key,
    s.customer_key,
    s.territory_key,
    s.order_quantity,
    p.product_price                                              AS unit_price,
    p.product_cost                                               AS unit_cost,
    CAST(s.order_quantity * p.product_price AS DECIMAL(18,2))    AS sales_amount,
    CAST(s.order_quantity * p.product_cost  AS DECIMAL(18,2))    AS cost_amount,
    CAST(s.order_quantity * (p.product_price - p.product_cost) AS DECIMAL(18,2)) AS profit_amount
FROM silver.sales_data AS s
INNER JOIN silver.product_lookup AS p
    ON s.product_key = p.product_key;
GO

PRINT 'SUCCESS: View gold.fact_sales created.';
GO

PRINT 'Gold Layer Views Creation Completed Successfully!';
GO

-- ==============================================================================
-- 3. SANITY CHECKS (read-only)
-- ==============================================================================
PRINT '--- Gold layer sanity checks ---';

-- Row count of every view
SELECT 'gold.dim_calendar'  AS view_name, COUNT_BIG(*) AS row_count FROM gold.dim_calendar
UNION ALL SELECT 'gold.dim_customers', COUNT_BIG(*) FROM gold.dim_customers
UNION ALL SELECT 'gold.dim_territory', COUNT_BIG(*) FROM gold.dim_territory
UNION ALL SELECT 'gold.dim_products',  COUNT_BIG(*) FROM gold.dim_products
UNION ALL SELECT 'gold.fact_returns',  COUNT_BIG(*) FROM gold.fact_returns
UNION ALL SELECT 'gold.fact_sales',    COUNT_BIG(*) FROM gold.fact_sales;

-- Gold facts must contain exactly the rows that Silver has
DECLARE @silver_sales   BIGINT = (SELECT COUNT_BIG(*) FROM silver.sales_data),
        @gold_sales     BIGINT = (SELECT COUNT_BIG(*) FROM gold.fact_sales),
        @silver_returns BIGINT = (SELECT COUNT_BIG(*) FROM silver.returns_data),
        @gold_returns   BIGINT = (SELECT COUNT_BIG(*) FROM gold.fact_returns);

PRINT CASE WHEN @silver_sales = @gold_sales
           THEN CONCAT('CHECK PASSED: fact_sales row count matches Silver (', FORMAT(@gold_sales, 'N0'), ')')
           ELSE CONCAT('CHECK FAILED: fact_sales has ', @gold_sales, ' rows but Silver has ', @silver_sales)
      END;

PRINT CASE WHEN @silver_returns = @gold_returns
           THEN CONCAT('CHECK PASSED: fact_returns row count matches Silver (', FORMAT(@gold_returns, 'N0'), ')')
           ELSE CONCAT('CHECK FAILED: fact_returns has ', @gold_returns, ' rows but Silver has ', @silver_returns)
      END;

-- Sales with a date missing from the calendar (should be 0)
SELECT COUNT_BIG(*) AS sales_rows_without_calendar_date
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_calendar AS d ON f.order_date = d.[date]
WHERE d.[date] IS NULL;

-- Quick business summary
SELECT
    d.[year],
    SUM(f.sales_amount)  AS total_sales,
    SUM(f.profit_amount) AS total_profit,
    COUNT(DISTINCT f.order_number) AS orders
FROM gold.fact_sales AS f
INNER JOIN gold.dim_calendar AS d ON f.order_date = d.[date]
GROUP BY d.[year]
ORDER BY d.[year];
GO