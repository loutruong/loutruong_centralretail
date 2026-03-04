-- Active: 1756983137726@@10.250.139.30@5432@bigc_tracking_db
WITH
	t_dwd AS (
		SELECT
			CASE
				WHEN LOWER(is_retargeting) IN ('true') THEN 'and_event_non_organic_retargeting'
				ELSE 'and_event_non_organic'
			END AS table_name,
			*
		FROM
			bigc_tracking_db.bigc_tracking.in_app_event_non_organic_androids
		WHERE
			1 = 1
			AND LOWER(is_primary_attribution) = 'true'
		UNION ALL
		--<< Break point inAPP
		SELECT
			CASE
				WHEN LOWER(is_retargeting) IN ('true') THEN 'ios_event_non_organic_retargeting'
				ELSE 'ios_event_non_organic'
			END AS table_name,
			*
		FROM
			bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
		WHERE
			1 = 1
			AND LOWER(is_primary_attribution) = 'true'
		UNION ALL
		--<< Break point inAPP
		SELECT
			'and_event_organic' AS table_name,
			*
		FROM
			bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
		WHERE
			1 = 1
			AND LOWER(is_primary_attribution) = 'true'
		UNION ALL
		--<< Break point inAPP
		SELECT
			'ios_event_organic' AS table_name,
			*
		FROM
			bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
		WHERE
			1 = 1
			AND LOWER(is_primary_attribution) = 'true'
	)
SELECT DISTINCT
	CASE
		WHEN event_time >= CURRENT_DATE - INTERVAL '90 day' THEN customer_user_id
		ELSE NULL
	END AS is_pur_l90d,
	CASE
		WHEN event_time >= CURRENT_DATE - INTERVAL '60 day'
		AND event_name NOT IN ('view_product') THEN customer_user_id
		ELSE NULL
	END AS is_pur_l60d,
	CASE
		WHEN event_time >= CURRENT_DATE - INTERVAL '30 day'
		AND event_name NOT IN ('view_product') THEN customer_user_id
		ELSE NULL
	END AS is_pur_l30d
FROM
	t_dwd
WHERE
	1 = 1
	AND event_time >= CURRENT_DATE - INTERVAL '90 day' --<< Rolling date D0 base
	AND event_name IN ('af_purchase', 'add_to_shopping_cart') --<< Event filter
;