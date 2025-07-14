
-- Working with dates
SELECT
	YEAR(order_date) as order_year,
	MONTH(order_date) as order_month,
	SUM(sales_amount) as total_sales,
	COUNT(DISTINCT customer_key) as total_customers,
	SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)


SELECT
	DATETRUNC(MONTH, order_date) as order_date,
	SUM(sales_amount) as total_sales,
	COUNT(DISTINCT customer_key) as total_customers,
	SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date)

-- Using format means that the date is now a string and can't be sorted correctly.
SELECT
	FORMAT(order_date, 'yyyy-MMM') as order_date,
	SUM(sales_amount) as total_sales,
	COUNT(DISTINCT customer_key) as total_customers,
	SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM')


-- Using Cumulative Analysis
SELECT
	order_date,
	total_sales,
	SUM(total_sales) OVER (ORDER BY order_date) as running_total_sales,
	avg_price,
	AVG(avg_price) OVER (ORDER BY order_date) as moving_avg_price
FROM
	(
	SELECT
		DATETRUNC(year, order_date) as order_date,
		SUM(sales_amount) as total_sales,
		AVG(price) as avg_price
	FROM gold.fact_sales
	WHERE order_date IS NOT NULL
	GROUP BY DATETRUNC(year, order_date)
	)t


-- Performance Analysis
WITH yearly_product_sales AS (
	SELECT
		YEAR(f.order_date) AS order_year,
		p.product_name,
		SUM(f.sales_amount) AS current_sales
	FROM gold.fact_sales f
		LEFT JOIN gold.dim_products p on f.product_key = p.product_key
	WHERE order_date IS NOT NULL
	GROUP BY YEAR(f.order_date), p.product_name
)

SELECT 
	order_year,
	product_name,
	current_sales,
	AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
	current_sales - AVG(current_sales) OVER(PARTITION BY product_name) as diff_avg,
	CASE WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) > 0 THEN 'Above avg'
		 WHEN current_sales - AVG(current_sales) OVER(PARTITION BY product_name) < 0 THEN 'Below avg'
		 ELSE 'Avg'
	END AS avg_change,
	LAG (current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS previous_year_sales,
	current_sales - LAG (current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS yoy_sales,
	CASE WHEN current_sales - LAG (current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
		 WHEN current_sales - LAG (current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
		 ELSE 'No change'
	END AS yoy_sales_change
FROM yearly_product_sales
ORDER BY product_name, order_year


WITH category_sales AS (
	SELECT
		category,
		SUM(sales_amount) total_sales
	FROM gold.fact_sales f
		LEFT JOIN gold.dim_products p on f.product_key = p.product_key
	GROUP BY category
)

SELECT
	category,
	total_sales,
	SUM(total_sales) OVER() overall_sales,
	CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER()) * 100, 2), '%') percentage_of_total
FROM category_sales


-- Data Segmentation
WITH product_segments AS (
SELECT
	product_key,
	product_name,
	cost,
	CASE WHEN cost < 100 THEN 'Below 100'
		 WHEN cost BETWEEN 100 AND 500 THEN '100-500'
		 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
		 ELSE 'Above 1000'
	END cost_range
FROM gold.dim_products
)

SELECT
	cost_range,
	COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range


/*
Group customers into thress segments based on their spending hehavior:
	- VIP: at least 12 motnhs of history and spending more than $5000
	- Regular: at least 12 months of history but spending $5000 or less
	- New: lifespan less than 12 months.
*/

WITH customer_spending AS (
SELECT
	f.customer_key,
	SUM(f.sales_amount) total_spending,
	MIN(order_date) first_order,
	MAX(order_date) last_order,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) life_span
FROM gold.fact_sales f
	LEFT JOIN gold.dim_customers c on f.customer_key = c.customer_key
GROUP BY f.customer_key
)

SELECT
	customer_segment,
	COUNT(customer_key) total_customers
FROM(
	SELECT 
		customer_key,
		total_spending,
		life_span,
		CASE WHEN life_span >= 12 AND total_spending > 5000 THEN 'VIP'
			 WHEN life_span >= 12 AND total_spending <= 5000 THEN 'Regular'
			 ELSE 'NEW'
		END customer_segment
	FROM customer_spending
	)t
GROUP BY customer_segment
ORDER BY customer_segment

