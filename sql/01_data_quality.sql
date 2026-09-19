-- Olist E-Commerce Sales & Customer Analytics
-- MySQL 8.0+; select your imported database in Workbench first.
-- Business analysis and data-quality checks with section comments.
-- Includes UPDATE statements in sections 7 and 11. Run section by section.
-- These transformations apply to the confirmed import artifacts documented in README.md.
-- NULL checks alone do not detect empty strings or zero dates before cleaning.


-- 1. Customer missing values
SELECT
    COUNT(*) AS total_rows,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(customer_unique_id IS NULL) AS missing_unique_id,
    SUM(customer_zip_code_prefix IS NULL) AS missing_zip,
    SUM(customer_city IS NULL) AS missing_city,
    SUM(customer_state IS NULL) AS missing_state
FROM customers;


-- 2. Order missing values
SELECT
    COUNT(*) AS total_rows,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(order_status IS NULL) AS missing_status,
    SUM(order_purchase_timestamp IS NULL) AS missing_purchase_date,
    SUM(order_approved_at IS NULL) AS missing_approved_date,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_date,
    SUM(order_delivered_customer_date IS NULL) AS missing_delivery_date,
    SUM(order_estimated_delivery_date IS NULL) AS missing_estimated_date
FROM orders;


-- 3. Product missing values
SELECT
    COUNT(*) AS total_rows,
    SUM(product_category_name IS NULL) AS missing_category,
    SUM(product_name_lenght IS NULL) AS missing_name_length,
    SUM(product_description_lenght IS NULL) AS missing_description_length,
    SUM(product_photos_qty IS NULL) AS missing_photos,
    SUM(product_weight_g IS NULL) AS missing_weight,
    SUM(product_length_cm IS NULL) AS missing_length,
    SUM(product_height_cm IS NULL) AS missing_height,
    SUM(product_width_cm IS NULL) AS missing_width
FROM products;


-- 4. Order-item missing values
SELECT
    COUNT(*) AS total_rows,
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(product_id IS NULL) AS missing_product_id,
    SUM(seller_id IS NULL) AS missing_seller_id,
    SUM(shipping_limit_date IS NULL) AS missing_shipping_date,
    SUM(price IS NULL) AS missing_price,
    SUM(freight_value IS NULL) AS missing_freight
FROM order_items;


-- 5. Product blanks and zeros
SELECT
    SUM(product_category_name = '') AS blank_category,
    SUM(product_name_lenght = 0) AS zero_name_length,
    SUM(product_description_lenght = 0) AS zero_description_length,
    SUM(product_photos_qty = 0) AS zero_photos,
    SUM(product_weight_g = 0) AS zero_weight,
    SUM(product_length_cm = 0) AS zero_length,
    SUM(product_height_cm = 0) AS zero_height,
    SUM(product_width_cm = 0) AS zero_width
FROM products;


-- 6. Inspect affected products
SELECT *
FROM products
WHERE product_category_name = ''
   OR product_name_lenght = 0
   OR product_description_lenght = 0
   OR product_photos_qty = 0
   OR product_weight_g = 0
   OR product_length_cm = 0
   OR product_height_cm = 0
   OR product_width_cm = 0
LIMIT 20;


-- 7. Confirmed product cleaning (changes data)
-- Source/Python cross-validation showed that product_weight_g contains
-- 2 genuinely missing values and 4 genuine zero-weight values.
-- Preserve/restore those four source zeros instead of treating them as missing.
SET SQL_SAFE_UPDATES = 0;

UPDATE products
SET
    product_category_name = NULLIF(product_category_name, ''),
    product_name_lenght = NULLIF(product_name_lenght, 0),
    product_description_lenght = NULLIF(product_description_lenght, 0),
    product_photos_qty = NULLIF(product_photos_qty, 0),
    product_length_cm = NULLIF(product_length_cm, 0),
    product_height_cm = NULLIF(product_height_cm, 0),
    product_width_cm = NULLIF(product_width_cm, 0);

-- Genuine zero-weight products in the source CSV.
-- This also restores them if an earlier cleaning pass converted them to NULL.
UPDATE products
SET product_weight_g = 0
WHERE product_id IN (
    '81781c0fed9fe1ad6e8c81fca1e1cb08',
    '8038040ee2a71048d4bdbbdc985b69ab',
    '36ba42dd187055e1fbe943b2d11430ca',
    'e673e90efa65a5409ff4196c038bb5af'
);

-- Convert only the remaining imported zero-weight placeholders to NULL.
UPDATE products
SET product_weight_g = NULL
WHERE product_weight_g = 0
  AND product_id NOT IN (
      '81781c0fed9fe1ad6e8c81fca1e1cb08',
      '8038040ee2a71048d4bdbbdc985b69ab',
      '36ba42dd187055e1fbe943b2d11430ca',
      'e673e90efa65a5409ff4196c038bb5af'
  );

SET SQL_SAFE_UPDATES = 1;


-- 8. Verify product cleaning
SELECT
    COUNT(*) AS total_rows,
    SUM(product_category_name IS NULL) AS missing_category,
    SUM(product_name_lenght IS NULL) AS missing_name_length,
    SUM(product_description_lenght IS NULL) AS missing_description_length,
    SUM(product_photos_qty IS NULL) AS missing_photos,
    SUM(product_weight_g IS NULL) AS missing_weight,
    SUM(product_weight_g = 0) AS genuine_zero_weights,
    SUM(product_length_cm IS NULL) AS missing_length,
    SUM(product_height_cm IS NULL) AS missing_height,
    SUM(product_width_cm IS NULL) AS missing_width
FROM products;

-- Expected weight validation after final cleaning:
-- missing_weight = 2
-- genuine_zero_weights = 4


-- 9. Inspect canceled and unavailable orders
SELECT
    order_id,
    order_status,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM orders
WHERE order_status IN ('canceled', 'unavailable')
LIMIT 30;


-- 10. Count zero dates using CAST
SELECT
    COUNT(*) AS total_orders,

    SUM(CAST(order_approved_at AS CHAR) = '0000-00-00 00:00:00')
        AS missing_approved,

    SUM(CAST(order_delivered_carrier_date AS CHAR) = '0000-00-00 00:00:00')
        AS missing_carrier,

    SUM(CAST(order_delivered_customer_date AS CHAR) = '0000-00-00 00:00:00')
        AS missing_customer_delivery,

    SUM(CAST(order_estimated_delivery_date AS CHAR) = '0000-00-00 00:00:00')
        AS missing_estimated

FROM orders;


-- 11. Confirmed zero-date cleaning (changes data)
SET SQL_SAFE_UPDATES = 0;

UPDATE orders
SET
    order_approved_at =
        CASE
            WHEN CAST(order_approved_at AS CHAR) = '0000-00-00 00:00:00'
            THEN NULL
            ELSE order_approved_at
        END,

    order_delivered_carrier_date =
        CASE
            WHEN CAST(order_delivered_carrier_date AS CHAR) = '0000-00-00 00:00:00'
            THEN NULL
            ELSE order_delivered_carrier_date
        END,

    order_delivered_customer_date =
        CASE
            WHEN CAST(order_delivered_customer_date AS CHAR) = '0000-00-00 00:00:00'
            THEN NULL
            ELSE order_delivered_customer_date
        END;

SET SQL_SAFE_UPDATES = 1;


-- 12. Verify order dates
SELECT
    COUNT(*) AS total_orders,
    SUM(order_approved_at IS NULL) AS missing_approved,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier,
    SUM(order_delivered_customer_date IS NULL) AS missing_customer_delivery,
    SUM(order_estimated_delivery_date IS NULL) AS missing_estimated
FROM orders;


-- 13. Payment missing values
-- order_payments
SELECT
    COUNT(*) AS total_rows,
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(payment_sequential IS NULL) AS missing_payment_sequence,
    SUM(payment_type IS NULL OR payment_type = '') AS missing_payment_type,
    SUM(payment_installments IS NULL) AS missing_installments,
    SUM(payment_value IS NULL) AS missing_payment_value
FROM order_payments;


-- 14. Review missing values
-- order_reviews
SELECT
    COUNT(*) AS total_rows,
    SUM(review_id IS NULL OR review_id = '') AS missing_review_id,
    SUM(order_id IS NULL OR order_id = '') AS missing_order_id,
    SUM(review_score IS NULL) AS missing_review_score,
    SUM(review_comment_title IS NULL OR review_comment_title = '') AS missing_title,
    SUM(review_comment_message IS NULL OR review_comment_message = '') AS missing_message,
    SUM(review_creation_date IS NULL) AS missing_creation_date,
    SUM(review_answer_timestamp IS NULL) AS missing_answer_timestamp
FROM order_reviews;


-- 15. Seller missing values
-- sellers
SELECT
    COUNT(*) AS total_rows,
    SUM(seller_id IS NULL OR seller_id = '') AS missing_seller_id,
    SUM(seller_zip_code_prefix IS NULL) AS missing_zip,
    SUM(seller_city IS NULL OR seller_city = '') AS missing_city,
    SUM(seller_state IS NULL OR seller_state = '') AS missing_state
FROM sellers;


-- 16. Duplicate key checks
-- 1. Duplicate customer IDs
SELECT customer_id, COUNT(*) AS occurrences
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- 2. Duplicate order IDs
SELECT order_id, COUNT(*) AS occurrences
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- 3. Duplicate product IDs
SELECT product_id, COUNT(*) AS occurrences
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;


-- 4. Duplicate seller IDs
SELECT seller_id, COUNT(*) AS occurrences
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;


-- 5. Duplicate order-item combination
SELECT
    order_id,
    order_item_id,
    COUNT(*) AS occurrences
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;


-- 17. Relationship checks
-- 1. Orders whose customer doesn't exist
SELECT COUNT(*) AS orders_without_customer
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 2. Order items whose order doesn't exist
SELECT COUNT(*) AS items_without_order
FROM order_items oi
LEFT JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 3. Order items whose product doesn't exist
SELECT COUNT(*) AS items_without_product
FROM order_items oi
LEFT JOIN products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- 4. Order items whose seller doesn't exist
SELECT COUNT(*) AS items_without_seller
FROM order_items oi
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- 5. Payments whose order doesn't exist
SELECT COUNT(*) AS payments_without_order
FROM order_payments op
LEFT JOIN orders o
    ON op.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 6. Reviews whose order doesn't exist
SELECT COUNT(*) AS reviews_without_order
FROM order_reviews r
LEFT JOIN orders o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 18. Business-value and timestamp checks
-- 1. Invalid product prices
SELECT COUNT(*) AS invalid_prices
FROM order_items
WHERE price <= 0;


-- 2. Invalid freight values
SELECT COUNT(*) AS invalid_freight
FROM order_items
WHERE freight_value < 0;


-- 3. Invalid payment values
SELECT COUNT(*) AS invalid_payments
FROM order_payments
WHERE payment_value < 0;


-- 4. Invalid review scores
SELECT COUNT(*) AS invalid_review_scores
FROM order_reviews
WHERE review_score < 1
   OR review_score > 5;


-- 5. Invalid payment installments
SELECT COUNT(*) AS negative_installments
FROM order_payments
WHERE payment_installments < 0;


-- 6. Purchase date after estimated delivery date
SELECT COUNT(*) AS invalid_estimated_dates
FROM orders
WHERE order_purchase_timestamp > order_estimated_delivery_date;


-- 7. Delivered to customer before purchase
SELECT COUNT(*) AS delivery_before_purchase
FROM orders
WHERE order_delivered_customer_date IS NOT NULL
  AND order_delivered_customer_date < order_purchase_timestamp;


-- 8. Carrier received order before purchase
SELECT COUNT(*) AS carrier_before_purchase
FROM orders
WHERE order_delivered_carrier_date IS NOT NULL
  AND order_delivered_carrier_date < order_purchase_timestamp;


-- 19. Inspect carrier anomalies
SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    TIMESTAMPDIFF(
        HOUR,
        order_delivered_carrier_date,
        order_purchase_timestamp
    ) AS hours_before_purchase
FROM orders
WHERE order_delivered_carrier_date IS NOT NULL
  AND order_delivered_carrier_date < order_purchase_timestamp
ORDER BY hours_before_purchase DESC
LIMIT 30;


-- 20. Summarize carrier anomalies
SELECT
    COUNT(*) AS affected_orders,
    MIN(TIMESTAMPDIFF(
        HOUR,
        order_delivered_carrier_date,
        order_purchase_timestamp
    )) AS min_hours_difference,
    MAX(TIMESTAMPDIFF(
        HOUR,
        order_delivered_carrier_date,
        order_purchase_timestamp
    )) AS max_hours_difference,
    AVG(TIMESTAMPDIFF(
        HOUR,
        order_delivered_carrier_date,
        order_purchase_timestamp
    )) AS avg_hours_difference
FROM orders
WHERE order_delivered_carrier_date IS NOT NULL
  AND order_delivered_carrier_date < order_purchase_timestamp;


-- 21. Installments, payment types and order statuses
-- Zero installments
SELECT COUNT(*) AS zero_installments
FROM order_payments
WHERE payment_installments = 0;


-- Payment types and their frequency
SELECT
    payment_type,
    COUNT(*) AS transactions
FROM order_payments
GROUP BY payment_type
ORDER BY transactions DESC;


-- Order statuses
SELECT
    order_status,
    COUNT(*) AS orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;
