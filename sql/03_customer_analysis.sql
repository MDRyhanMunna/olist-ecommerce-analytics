-- Olist E-Commerce Sales & Customer Analytics
-- MySQL 8.0+; select your imported database in Workbench first.
-- Business analysis and data-quality checks with section comments.


-- 1. Customers by state
SELECT
    c.customer_state AS state,

    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,

    COUNT(DISTINCT o.order_id) AS orders,

    ROUND(SUM(oi.price), 2) AS revenue,

    ROUND(
        SUM(oi.price) * 100.0 /
        SUM(SUM(oi.price)) OVER (),
        2
    ) AS revenue_percentage,

    ROUND(
        SUM(oi.price) /
        COUNT(DISTINCT c.customer_unique_id),
        2
    ) AS revenue_per_customer

FROM customers c

JOIN orders o
    ON c.customer_id = o.customer_id

JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_state

ORDER BY revenue DESC;


-- 2. One-time and repeat customers
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,

    COUNT(*) AS customers,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage

FROM customer_orders

GROUP BY
    CASE
        WHEN total_orders = 1 THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END;


-- 3. Highest-value customers
SELECT
    c.customer_unique_id,

    COUNT(DISTINCT o.order_id) AS total_orders,

    COUNT(oi.order_item_id) AS products_purchased,

    ROUND(SUM(oi.price), 2) AS total_spent,

    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS avg_order_value

FROM customers c

JOIN orders o
    ON c.customer_id = o.customer_id

JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY c.customer_unique_id

ORDER BY total_spent DESC

LIMIT 10;


-- 4. Spending by customer type
WITH customer_summary AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(oi.price) AS total_spent
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,

    COUNT(*) AS customers,

    ROUND(AVG(total_spent), 2) AS avg_spend_per_customer,

    ROUND(SUM(total_spent), 2) AS total_revenue,

    ROUND(
        SUM(total_spent) * 100.0 /
        SUM(SUM(total_spent)) OVER (),
        2
    ) AS revenue_percentage

FROM customer_summary

GROUP BY
    CASE
        WHEN total_orders = 1 THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END;


-- 5. Average customer spending
WITH customer_spending AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price) AS total_spent
    FROM customers c
    JOIN orders o
        ON c.customer_id = o.customer_id
    JOIN order_items oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS unique_customers,
    ROUND(AVG(total_spent), 2) AS avg_spend_per_customer,
    ROUND(MIN(total_spent), 2) AS lowest_customer_spend,
    ROUND(MAX(total_spent), 2) AS highest_customer_spend
FROM customer_spending;
