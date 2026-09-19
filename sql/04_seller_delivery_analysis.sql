-- Olist E-Commerce Sales & Customer Analytics
-- MySQL 8.0+; select your imported database in Workbench first.
-- Delivery analysis using calendar-date classification and fractional-day durations.
-- Duration uses seconds / 86400: 96,470 valid orders; avg 12.56, min 0.53, max 209.63 days.
-- Carrier anomalies are retained. For purchase-to-carrier metrics, require
-- order_delivered_carrier_date >= order_purchase_timestamp and both dates non-NULL.
-- Current delivery duration uses purchase-to-customer dates, not carrier dates.


-- 1. Top sellers
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,

    COUNT(DISTINCT o.order_id) AS orders,

    COUNT(oi.order_item_id) AS products_sold,

    ROUND(SUM(oi.price), 2) AS revenue,

    ROUND(
        SUM(oi.price) / COUNT(DISTINCT o.order_id),
        2
    ) AS revenue_per_order

FROM sellers s

JOIN order_items oi
    ON s.seller_id = oi.seller_id

JOIN orders o
    ON oi.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    s.seller_id,
    s.seller_city,
    s.seller_state

ORDER BY revenue DESC

LIMIT 10;


-- 2. Delivery duration
SELECT
    COUNT(*) AS delivered_orders,

    ROUND(
        AVG(
            TIMESTAMPDIFF(
                SECOND,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        ) / 86400,
        2
    ) AS avg_delivery_days,

    ROUND(
        MIN(
            TIMESTAMPDIFF(
                SECOND,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        ) / 86400,
        2
    ) AS fastest_delivery_days,

    ROUND(
        MAX(
            TIMESTAMPDIFF(
                SECOND,
                order_purchase_timestamp,
                order_delivered_customer_date
            )
        ) / 86400,
        2
    ) AS slowest_delivery_days

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date >= order_purchase_timestamp;


-- 3. On-time and late delivery
SELECT
    CASE
        WHEN DATE(order_delivered_customer_date) <= DATE(order_estimated_delivery_date)
            THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,

    COUNT(*) AS orders,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage

FROM orders

WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL

GROUP BY
    CASE
        WHEN DATE(order_delivered_customer_date) <= DATE(order_estimated_delivery_date)
            THEN 'On Time'
        ELSE 'Late'
    END;
