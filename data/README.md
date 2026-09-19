# Data setup and exports

Obtain the **Brazilian E-Commerce Public Dataset by Olist** from its Olist dataset page on Kaggle. Follow the source's current access and license terms; data are not redistributed in this repository.

Place these files together in the folder referenced by the notebook's `base_path` variable. If you follow a repository-style layout, `data/raw/` is recommended:

- `olist_customers_dataset.csv`
- `olist_orders_dataset.csv`
- `olist_order_items_dataset.csv`
- `olist_order_payments_dataset.csv`
- `olist_order_reviews_dataset.csv`
- `olist_products_dataset.csv`
- `olist_sellers_dataset.csv`
- `product_category_name_translation.csv`

The MySQL project also documents `olist_geolocation_dataset.csv`; the notebook and current business queries do not use it.

## Import and cleaning

For MySQL, map the CSVs to `customers`, `orders`, `order_items`, `order_payments`, `order_reviews`, `products`, `sellers`, `category_translation`, and optionally `geolocation`. A schema/import script is not supplied. Keep identifiers as text and missing timestamps nullable.

The historical MySQL review import required corrected quote/escape handling; the repair script and repaired CSV are not bundled. Check that the imported review table contains 99,224 rows. Do not remove repeated review IDs indiscriminately. See the main README for the exact historical issue.

Python reads the source CSVs directly with pandas. Its missing-value handling differs from the historical MySQL import: blank CSV values are read as missing values and invalid dates are coerced to missing where date parsing is applied. Carrier-before-purchase anomalies are flagged and retained.

For `product_weight_g`, source CSV validation shows **2 missing values and 4 source-recorded zero values**. The notebook preserves those zero values instead of automatically converting them to missing. Their presence in the source does not prove that the physical product weight is actually zero.

## Notebook exports

Running the notebook creates the folder specified by 'processed_path' and writes:

- `monthly_sales.csv`
- `category_sales.csv`
- `customer_summary.csv`
- `customer_value.csv`
- `delivery_satisfaction.csv`
- `review_distribution.csv`
- `category_performance.csv`
- `powerbi_orders.csv`
- `powerbi_sales.csv`
- `powerbi_reviews.csv`

`powerbi_orders` contains one row per delivered order (96,478); `powerbi_sales` contains delivered item rows (110,197); `powerbi_reviews` contains delivered-order review rows (96,361). Keep these different levels of detail separate to avoid multiplying revenue or changing review weights.

Category analysis first deduplicates `order_id + category`, then joins review rows. `total_reviews`, average rating, and positive/negative percentages are all calculated from those resulting review rows, matching the final SQL logic.

The notebook uses editable `base_path` and `processed_path` variables rather than environment-variable overrides. In Colab, mount Google Drive and edit those two path variables so they point to your own project folders before running the remaining cells.

## Refresh and validation

Update the Power BI source paths to your generated files before refreshing. Check all required queries, relationships, and slicer interactions. Validate the headline values against the main README. On-time delivery is 89,936 / 96,470 = 93.23%, excluding eight delivered orders with missing actual delivery dates.

Raw and processed data directories are ignored by Git. This file keeps data setup instructions visible without bundling datasets.
