-- Olist E-Commerce Sales & Customer Analytics
-- MySQL 8.0+; separate sales and review aggregation.
-- Ratings describe whole orders. Deduplicate order-category pairs before attaching reviews.
-- Category total_reviews, averages and percentages use review rows after order-category deduplication.
-- Repeated review IDs are not blindly removed. Multi-category orders contribute to each category.
-- Combined revenue includes all delivered items within each qualifying category.
-- >=100 review-row filter and top-15 limit restrict category display only.
-- Delivery reviews: On Time 89,944 / 4.29 / 82.64% positive / 9.28% negative;
-- Late 6,409 / 2.27 / 26.71% positive / 62.41% negative.

-- 1. Delivery and review scores
SELECT
    CASE
        WHEN DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
            THEN 'On Time'
        ELSE 'Late'
    END AS delivery_status,

    COUNT(*) AS reviews,

    ROUND(AVG(r.review_score), 2) AS avg_review_score,

    ROUND(
        SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS positive_review_percentage,

    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS negative_review_percentage

FROM orders o

JOIN order_reviews r
    ON o.order_id = r.order_id

WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL

GROUP BY
    CASE
        WHEN DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
            THEN 'On Time'
        ELSE 'Late'
    END;


-- 2. Rating distribution
SELECT
    r.review_score,

    COUNT(*) AS reviews,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage

FROM order_reviews r

JOIN orders o
    ON r.order_id = o.order_id

WHERE o.order_status = 'delivered'

GROUP BY r.review_score

ORDER BY r.review_score;


-- 3. Overall satisfaction
SELECT
    COUNT(*) AS total_reviews,

    ROUND(AVG(r.review_score), 2) AS avg_review_score,

    ROUND(
        SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS positive_percentage,

    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS negative_percentage

FROM order_reviews r

JOIN orders o
    ON r.order_id = o.order_id

WHERE o.order_status = 'delivered';


-- 4. Category satisfaction at order-category grain
-- First reduce item-level data to one row per order + category, then attach review rows.
WITH order_categories AS (
    SELECT DISTINCT
        o.order_id,
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category
    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
)

SELECT
    oc.category,
    COUNT(*) AS total_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,

    ROUND(
        SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS positive_percentage,

    ROUND(
        SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS negative_percentage

FROM order_categories oc
JOIN order_reviews r
    ON oc.order_id = r.order_id

GROUP BY oc.category

HAVING COUNT(*) >= 100

ORDER BY avg_review_score DESC;

-- 5. Independently aggregated category revenue and satisfaction
WITH category_revenue AS (
    SELECT
        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category,

        COUNT(DISTINCT o.order_id) AS orders,
        COUNT(*) AS products_sold,
        SUM(oi.price) AS revenue

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
),

order_categories AS (
    SELECT DISTINCT
        o.order_id,

        COALESCE(
            ct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS category

    FROM orders o
    JOIN order_items oi
        ON o.order_id = oi.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name

    WHERE o.order_status = 'delivered'
),

category_reviews AS (
    SELECT
        oc.category,

        COUNT(*) AS total_reviews,

        AVG(r.review_score) AS avg_review_score,

        SUM(CASE
            WHEN r.review_score <= 2 THEN 1
            ELSE 0
        END) * 100.0 / COUNT(*) AS negative_review_percentage

    FROM order_categories oc
    JOIN order_reviews r
        ON oc.order_id = r.order_id

    GROUP BY oc.category
)

SELECT
    cr.category,
    cr.orders,
    cr.products_sold,
    ROUND(cr.revenue, 2) AS revenue,

    rv.total_reviews,
    ROUND(rv.avg_review_score, 2) AS avg_review_score,
    ROUND(rv.negative_review_percentage, 2)
        AS negative_review_percentage

FROM category_revenue cr

LEFT JOIN category_reviews rv
    ON cr.category = rv.category

WHERE rv.total_reviews >= 100

ORDER BY cr.revenue DESC

LIMIT 15;
