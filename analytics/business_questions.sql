/*
===============================================================================
script Name:   Business_Questions.sql
DESCription:   solves 8 levels of business questions using Advanced SQL.
               Includes KPIs, Window Functions, CTEs, and Cohort Analysis.
Author:        [Saeed Ahmed]
===============================================================================
*/

-- ============================================================================
-- 0. EXECUTIVE KPI DASHBOARD (snapshot)
-- ============================================================================
SELECT 'Total Orders' AS MEASURE, CAST(COUNT(DISTINCT order_number) AS VARCHAR)  AS Value FROM gold.fact_sales
UNION ALL
SELECT 'Total Revenue', CAST(SUM(sales_amount) AS VARCHAR ) FROM gold.fact_sales
UNION ALL
SELECT 'Total Profit',CAST(SUM(s.sales_amount - (p.product_cost * s.order_quantity)) AS VARCHAR) FROM gold.fact_sales AS s LEFT JOIN gold.dim_products AS p ON s.product_key = p.product_key
UNION ALL
SELECT 'Return Rate', CAST(CAST((SELECT SUM(return_quantity) FROM gold.fact_returns) * 100.0 / NULLIF((SELECT SUM(order_quantity) FROM gold.fact_sales), 0) AS DECIMAL(10,2)) AS VARCHAR) + '%'
UNION ALL
SELECT 'Avg Order Value', CAST(CAST(SUM(sales_amount) / NULLIF(COUNT(DISTINCT order_number), 0) AS DECIMAL(10,2)) AS VARCHAR) FROM gold.fact_sales;


-- ============================================================================
-- Level 1: Regional performance (Aggregation)
-- ============================================================================
SELECT TOp 10
    t.Region,
    COUNT(DISTINCT order_number) AS total_orders,
    SUM(sales_amount) AS total_revenue
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_territory AS t ON s.territory_key = t.sales_territory_key
GROUP BY t.Region
ORDER BY total_revenue DESC;


-- ============================================================================
-- Level 2: Return Rates by Category (Handling Fan Trap)
-- ============================================================================
WITH sales_summary AS (
    SELECT p.category_name, 
    SUM(order_quantity) AS total_quantity_sold
    FROM gold.fact_sales s
    JOIN gold.dim_products p ON s.product_key = p.product_key
    GROUP BY p.category_name
),
    returns_summary AS (
    SELECT p.category_name, 
    SUM(return_quantity) AS total_quantity_returned
    FROM gold.fact_returns r
    JOIN gold.dim_products p ON r.product_key = p.product_key
    GROUP BY p.category_name
)
SELECT 
s.category_name,
s.total_quantity_sold,
r.total_quantity_returned,
CAST(CAST(r.total_quantity_returned * 100.0 / s.total_quantity_sold AS DECIMAL(10,1))AS VARCHAR) + '%' AS return_rate
FROM sales_summary AS s
JOIN returns_summary AS r
ON s.category_name = r.category_name
ORDER BY return_rate DESC



-- ============================================================================
-- Level 3: Top Customers per Year (Ranking Window Function)
-- ============================================================================
WITH customer_rank AS (
    SELECT
        YEAR(s.order_date) AS order_year,
        c.full_name,
        SUM(sales_amount) AS total_revenue,
        RANK() OVER (PARTITION BY YEAR(s.order_date) ORDER BY SUM(sales_amount) DESC) AS rank_num
    FROM gold.fact_sales AS s
    JOIN gold.dim_customers AS C ON s.customer_key = c.customer_key
    GROUP BY YEAR(s.order_date), c.full_name
)
SELECT * 
FROM customer_rank WHERE rank_num <= 3;


-- ============================================================================
-- Level 4: Month-over-Month Growth for each Year (Lag Window Function)
-- ============================================================================

WITH monthly_sales AS (
	SELECT 
		YEAR(order_date) AS [year],
		DATETRUNC(MONTH, order_date) start_of_month,
		SUM(sales_amount) AS current_month_rev,
		LAG(SUM(sales_amount)) OVER (PARTITION BY YEAR(order_date) ORDER BY DATETRUNC(MONTH, order_date)) AS previous_month_rev
	FROM gold.fact_sales
	GROUP BY YEAR(order_date),DATETRUNC(MONTH, order_date)
)
SELECT
	start_of_month,
	current_month_rev,
	previous_month_rev,
	CAST(CAST((current_month_rev - previous_month_rev) * 100.0 / NULLIF(previous_month_rev, 0) AS DECIMAL(10,2)) AS VARCHAR) + '%'  AS growth_rate
FROM monthly_sales;


-- ============================================================================
-- Level 5: Rolling Total Revenue (Cumulative SUM)
-- ============================================================================
SELECT 
    order_date,
    SUM(sales_amount) AS daily_revenue,
    SUM(SUM(sales_amount)) OVER (ORDER BY order_date) AS running_total
FROM gold.fact_sales
WHERE YEAR(order_date) = 2022
GROUP BY order_date;


-- ============================================================================
-- Level 6: "Gold star" Customers (Cohort Analysis)
-- ============================================================================
SELECT 
    c.full_name,
    SUM(s.sales_amount) AS total_spent,
    COUNT(DISTINCT EOMONTH(s.order_date)) AS distict_months_bought
FROM gold.fact_sales AS s
JOIN gold.dim_customers AS c ON s.customer_key = c.customer_key
GROUP BY c.full_name
HAVING SUM(s.sales_amount) >= 5000 
   AND COUNT(DISTINCT EOMONTH(s.order_date)) >= 3;


-- ============================================================================
-- Level 7: pareto Analysis (80/20 Rule)
-- ============================================================================
WITH product_revenue AS (
    SELECT p.product_name, 
	SUM(s.sales_amount) AS revenue
    FROM gold.fact_sales s 
	JOIN gold.dim_products p 
	ON s.product_key = p.product_key
    GROUP BY p.product_name
),
	cumulative AS (
    SELECT 
        product_name, 
		revenue,
        SUM(revenue) OVER (ORDER BY revenue DESC) AS running_total,
        SUM(revenue) OVER () AS grand_total
    FROM product_revenue
)
SELECT 
	product_name, 
	revenue, 
	running_total,
	grand_total,
    CAST(running_total * 100.0 / grand_total AS DECIMAL(10,2)) AS cumulative_pct
FROM cumulative
WHERE running_total * 100.0 / grand_total <= 80;


-- ============================================================================
-- Level 8: Market BASKET Analysis (Products Bought Together)
-- ============================================================================
SELECT TOP 3
    p1.product_name AS product_A,
    p2.product_name AS product_B,
    COUNT(*) AS times_bought_together
FROM gold.fact_sales s1
JOIN gold.fact_sales s2 ON s1.order_number = s2.order_number AND s1.product_key < s2.product_key
JOIN gold.dim_products p1 ON s1.product_key = p1.product_key
JOIN gold.dim_products p2 ON s2.product_key = p2.product_key
GROUP BY p1.product_name, p2.product_name
ORDER BY times_bought_together DESC;