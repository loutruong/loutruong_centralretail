-- hamper_data - Execution time: 34.13 seconds 
--Hamper Data
WITH
	tet_2024_data AS (
		SELECT
			sale_date,
			sale_date + 354    tet_mapping,
			site_code,
			SUM(pos_net_sales) net_sales
		FROM
			FACT_SALE_ORDER_ITEM i
			JOIN HAMPER_SKU_2024 s ON i.product_code = s.product_code
		WHERE
			1 = 1
			AND SALE_DATE >= '27-Dec-2023'
			AND SALE_DATE < '26-Feb-2024'
		GROUP BY
			sale_date,
			site_code
	),
	tet_2025_data AS (
		SELECT
			sale_date,
			sale_date - 354    tet_mapping,
			site_code,
			SUM(pos_net_sales) net_sales
		FROM
			FACT_SALE_ORDER_ITEM i
			JOIN HAMPER_SKU_2025 s ON i.product_code = s.product_code
		WHERE
			1 = 1
			AND SALE_DATE >= '15-Dec-2024'
			AND SALE_DATE < '14-Feb-2025'
		GROUP BY
			sale_date,
			site_code
	),
	raw_data AS (
		SELECT
			i.sale_date,
			i.order_code,
			i.online_channel,
			i.pos_no,
			i.site_code,
			i.product_code,
			i.barcode_gold,
			CASE
				WHEN i.sale_type = 'Normal' THEN 'Normal'
				ELSE 'Promotion'
			END promo_type,
			i.quantity,
			i.net_sales,
			i.gold_margin
		FROM
			nguyenthelam.sale_order_item_ytd i
			JOIN HAMPER_SKU_2025 s ON i.product_code = s.product_code
		WHERE
			1 = 1
			AND (
				SALE_DATE >= '27-Dec-2023'
				AND SALE_DATE < '26-Feb-2024'
				OR SALE_DATE >= '15-Dec-2024'
				AND SALE_DATE < '14-Feb-2025'
			)
	),
	single_b2b AS (
		SELECT DISTINCT
			order_code
		FROM
			raw_data
		WHERE
			quantity >= 30
			AND net_sales >= 2000000
	),
	dup_order AS (
		SELECT
			i.*,
			y.quantity  total_qty,
			y.net_sales total_net_sales,
			CASE
				WHEN i.quantity >= 30
				AND i.net_sales >= 2000000 THEN 1
				ELSE 0
			END is_single_B2B -- step 1
,
			CASE
				WHEN (
					COUNT(DISTINCT i.order_code) OVER (
						PARTITION BY
							i.site_code,
							i.sale_date,
							i.pos_no,
							y.quantity,
							y.net_sales
					)
				) * NVL2 (sb.order_code, 0, 1) > 1 THEN 1
				ELSE 0
			END is_dup
		FROM
			raw_data i
			LEFT JOIN nguyenthelam.sale_order_ytd y ON i.order_code = y.order_code
			LEFT JOIN single_b2b sb ON i.order_code = sb.order_code
	),
	dup_b2b AS (
		SELECT
			s.*,
			CASE
				WHEN SUM(quantity * is_dup) OVER (
					PARTITION BY
						sale_date,
						site_code,
						barcode_gold,
						is_dup,
						online_channel
				) >= 30 THEN 1
				ELSE 0
			END is_dup_b2b -- step 2
		FROM
			dup_order s
	),
	all_order AS (
		SELECT
			d.*,
			CASE
				WHEN is_single_b2b + is_dup_b2b > 0 THEN 1
				ELSE -1
			END sale_type
		FROM
			dup_b2b d
	),
	b2b_b2c_data AS (
		SELECT
			sale_date,
			site_code,
			bs.sitename site_name,
			region,
			SUM(
				CASE
					WHEN sale_type = 1 THEN net_sales
					ELSE 0
				END
			) B2B_sales,
			SUM(
				CASE
					WHEN sale_type = -1 THEN net_sales
					ELSE 0
				END
			) B2C_sales,
			SUM(
				CASE
					WHEN sale_type = 1 THEN gold_margin
					ELSE 0
				END
			) B2B_margin,
			SUM(
				CASE
					WHEN sale_type = -1 THEN gold_margin
					ELSE 0
				END
			) B2C_margin
		FROM
			all_order a
			LEFT JOIN brand_site bs ON a.site_code = bs.siteid
		GROUP BY
			sale_date,
			site_code,
			bs.sitename,
			region
	),
	final_data AS (
		SELECT
			COALESCE(t.site_code, t1.site_code)   site_code,
			bs.sitename                           site_name,
			bs.region                             region,
			COALESCE(t.sale_date, t1.tet_mapping) tet_2024,
			COALESCE(t1.sale_date, t.tet_mapping) tet_2025,
			t.net_sales                           sales_2024,
			t1.net_sales                          sales_2025
		FROM
			tet_2024_data t
			FULL JOIN tet_2025_data t1 ON t.tet_mapping = t1.sale_date
			AND t.site_code = t1.site_code
			LEFT JOIN BRAND_SITE bs ON COALESCE(t.site_code, t1.site_code) = bs.siteid
	)
SELECT
	f.site_code,
	f.site_name,
	f.region,
	tet_2024,
	tet_2025,
	sales_2024,
	sales_2025,
	b.b2b_sales   b2b_sales_2024,
	b.b2c_sales   b2c_sales_2024,
	b.b2b_margin  b2b_margin_2024,
	b.b2c_margin  b2c_margin_2024,
	b2.b2b_sales  b2b_sales_2025,
	b2.b2c_sales  b2c_sales_2025,
	b2.b2b_margin b2b_margin_2025,
	b2.b2c_margin b2c_margin_2025
FROM
	final_data f
	LEFT JOIN b2b_b2c_data b ON f.tet_2024 = b.sale_date
	AND f.site_code = b.site_code
	LEFT JOIN b2b_b2c_data b2 ON f.tet_2025 = b2.sale_date
	AND f.site_code = b2.site_code
ORDER BY
	1,
	2,
	3,
	4
;