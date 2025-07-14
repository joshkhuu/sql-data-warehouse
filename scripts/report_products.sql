/*
============================================================================================
Customer Report
============================================================================================
Purpose:
	- This report cosolidates key product metrics and behaviours

Highlights:
	1. Gathers eseential fields such as product_name, category, subcategory, and cost.
	2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers
	3. Aggregates product-level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customer (unique)
		- life span (in months)
	4. Calculate valuable KPIs:
		- recency (months since last sale)
		- average order revenue(AOR)
		- average monthly revenue
============================================================================================
*/

CREATE VIEW gold.report_products AS
-- Base Query
WITH base_query AS (
SELECT 
	f.order_number,
	f.order_date,
	f.customer_key,
	f.sales_amount,
	f.quantity,
	f.product_key,
	p.product_line,
	p.product_name,
	p.category,
	p.subcategory,
	p.cost
FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p on f.product_key = p.product_key
WHERE order_date IS NOT NULL
)

, product_aggregation AS(
-- Prouct Aggregations:
SELECT
	product_key,
	product_line,
	product_name,
	category,
	subcategory,
	cost,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) life_span,
	MAX(order_date) last_sale_date,
	COUNT(DISTINCT order_number) total_orders,
	COUNT(DISTINCT customer_key) total_customers,
	SUM(sales_amount) total_sales,
	SUM(quantity) total_quantity,
	ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1) avg_selling_price
FROM base_query
GROUP BY
	product_key,
	product_line,
	product_name,
	category,
	subcategory,
	cost
)

SELECT
	product_key,
	product_line,
	product_name,
	category,
	subcategory,
	cost,
	life_span,
	last_sale_date,
	total_orders,
	total_customers,
	total_sales,
	total_quantity,
	avg_selling_price,
	DATEDIFF(month, last_sale_date, GETDATE()) recency_in_months,
	CASE WHEN total_sales > 50000 THEN 'High-Performer'
		 WHEN total_sales >= 10000 THEN 'Mid-Range'
		 ELSE 'Low-Performer'
	END product_segement,
	CASE WHEN total_orders = 0 THEN 0
		 ELSE total_sales / total_orders
	END avg_order_revenue,
	CASE WHEN life_span = 0 THEN total_sales
		 ELSE total_sales / life_span
	END avg_monthly_revenue
FROM product_aggregation
