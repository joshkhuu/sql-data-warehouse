/*
============================================================================================
Customer Report
============================================================================================
Purpose:
	- This report consolidates key customer metrics and behaviours

Highlights:
	1. Gather essential fields such as names, ages, and transaction details.
	2. Segments customer into categories (VIP, Regular, New) and age groups
	3. Aggregate customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	4. Calculate valuable KPIs:
		- recency (months since last order)
		- average order vlaue
		- average monthly spend
============================================================================================
*/

CREATE VIEW gold.report_customers AS
WITH base_query AS(
-- Base Query: Retrieves core columns from tables
SELECT
	f.order_number,
	f.product_key,
	f.order_date,
	f.sales_amount,
	f.quantity,
	c.customer_key,
	c.customer_number,
	CONCAT(c.first_name, ' ', c.last_name) customer_name,
	DATEDIFF(year, c.birthdate, GETDATE()) age
FROM gold.fact_sales f
	LEFT JOIN gold.dim_customers c on f.customer_key = c.customer_key
WHERE order_date IS NOT NULL
)

-- Customer Aggregations: Summarise key metrics at the customer level
, customer_aggregation AS (
SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	COUNT(DISTINCT order_number) total_orders,
	SUM(sales_amount) total_sales,
	SUM(quantity) total_quantity,
	COUNT(DISTINCT  product_key) as total_products,
	MAX(order_date) last_order_date,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) life_span
FROM base_query
GROUP BY customer_key,
	customer_number,
	customer_name,
	age
)

SELECT
	customer_key,
	customer_number,
	customer_name,
	age,
	CASE WHEN age < 20 THEN 'Under 20'
		 WHEN age BETWEEN 20 and 29 THEN '20-29'
		 WHEN age BETWEEN 30 and 39 THEN '30-39'
		 WHEN age BETWEEN 40 and 49 THEN '40-49'
		 ELSE '50 and above'
	END age_group,
	CASE WHEN life_span >= 12 AND total_sales > 5000 THEN 'VIP'
		 WHEN life_span >= 12 AND total_sales <= 5000 THEN 'Regular'
		 ELSE 'NEW'
	END customer_segment,
	last_order_date,
	DATEDIFF(month, last_order_date, GETDATE()) recency,
	total_orders,
	total_sales,
	total_quantity,
	total_products,
	life_span,
	-- Compute average order value
	CASE when total_sales = 0 THEN 0
		ELSE total_sales / total_orders 
	END avg_order_value,
	-- Compute average monthly spend
	CASE when life_span = 0 THEN total_sales
		ELSE total_sales / life_span
	END avg_monthly_spend
FROM customer_aggregation
