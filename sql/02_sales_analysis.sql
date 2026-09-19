-- Olist E-Commerce Sales & Customer Analytics
-- MySQL 8.0+; select your imported database in Workbench first.
-- Conversation SQL with final validated executive-customer correction.
-- Executive KPI: 96,478 delivered orders; 93,358 unique customers.


-- 1. Order status and item value
SELECT
    o.order_status,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
GROUP BY o.order_status
ORDER BY product_revenue DESC;


-- 2. Executive KPIs
SELECT
    COUNT(DISTINCT o.order_id) AS total_delivered_orders,

    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,

    COUNT(oi.order_item_id) AS products_sold,

    ROUND(SUM(oi.price), 2) AS total_revenue,

    ROUND(SUM(oi.freight_value), 2) AS total_freight,

    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_value,

    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value

FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id

JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered';


-- 3. Monthly sales
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,

    COUNT(DISTINCT o.order_id) AS total_orders,

    COUNT(oi.order_item_id) AS products_sold,

    ROUND(SUM(oi.price), 2) AS revenue,

    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value

FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')

ORDER BY month;


-- 4. Dataset coverage
SELECT
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date,
    DATEDIFF(
        MAX(order_purchase_timestamp),
        MIN(order_purchase_timestamp)
    ) AS dataset_days
FROM orders;


-- 5. Delivered purchase coverage
SELECT
    MIN(order_purchase_timestamp) AS first_delivered_purchase,
    MAX(order_purchase_timestamp) AS last_delivered_purchase
FROM orders
WHERE order_status = 'delivered';


-- 6. Top five revenue months
SELECT
    DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS average_order_value
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY revenue DESC
LIMIT 5;


-- 7. Top categories by revenue
SELECT
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category,

    COUNT(DISTINCT o.order_id) AS orders,

    COUNT(*) AS products_sold,

    ROUND(SUM(oi.price), 2) AS revenue,

    ROUND(AVG(oi.price), 2) AS avg_product_price,

    ROUND(
        SUM(oi.price) * 100.0 /
        SUM(SUM(oi.price)) OVER (),
        2
    ) AS revenue_percentage

FROM orders o

JOIN order_items oi
    ON o.order_id = oi.order_id

JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name

WHERE o.order_status = 'delivered'

GROUP BY
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )

ORDER BY revenue DESC

LIMIT 15;


-- 8. Top products by revenue
SELECT
    oi.product_id,

    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category,

    COUNT(DISTINCT o.order_id) AS orders,

    COUNT(*) AS units_sold,

    ROUND(SUM(oi.price), 2) AS revenue,

    ROUND(AVG(oi.price), 2) AS avg_selling_price

FROM orders o

JOIN order_items oi
    ON o.order_id = oi.order_id

JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name

WHERE o.order_status = 'delivered'

GROUP BY
    oi.product_id,
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )

ORDER BY revenue DESC

LIMIT 10;


-- 9. Top products by units
SELECT
    oi.product_id,

    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS category,

    COUNT(*) AS units_sold,

    COUNT(DISTINCT o.order_id) AS orders,

    ROUND(SUM(oi.price), 2) AS revenue,

    ROUND(AVG(oi.price), 2) AS avg_selling_price

FROM orders o

JOIN order_items oi
    ON o.order_id = oi.order_id

JOIN products p
    ON oi.product_id = p.product_id

LEFT JOIN category_translation ct
    ON p.product_category_name = ct.product_category_name

WHERE o.order_status = 'delivered'

GROUP BY
    oi.product_id,
    COALESCE(
        ct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    )

ORDER BY units_sold DESC

LIMIT 10;


-- 10. Payment methods
SELECT
    op.payment_type,

    COUNT(DISTINCT op.order_id) AS orders,

    COUNT(*) AS payment_transactions,

    ROUND(SUM(op.payment_value), 2) AS payment_value,

    ROUND(
        SUM(op.payment_value) * 100.0 /
        SUM(SUM(op.payment_value)) OVER (),
        2
    ) AS payment_percentage,

    ROUND(AVG(op.payment_installments), 2) AS avg_installments

FROM order_payments op

JOIN orders o
    ON op.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY op.payment_type

ORDER BY payment_value DESC;
