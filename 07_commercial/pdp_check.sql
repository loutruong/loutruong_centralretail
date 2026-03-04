WITH
	t_dwd AS (
		SELECT
			*
		FROM
			(
				SELECT
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_non_organic_androids
				UNION ALL
				SELECT
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
				UNION ALL
				SELECT
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
				UNION ALL
				SELECT
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
			)
		WHERE
			1 = 1
			AND LOWER(is_primary_attribution) = 'true'
			AND event_time >= '2025-11-07 00:00:00+07' --<< Controller
			AND event_name IN ('view_product')
	)
SELECT
	TO_CHAR(event_time, 'YYYY-MM-DD') AS ds,
	CASE
		WHEN event_value IS json THEN (event_value::jsonb -> 'metadata' ->> 'barcode')::DOUBLE PRECISION
		ELSE NULL
	END AS prd_id
	-- ,
	-- CASE
	-- 	WHEN event_value IS json THEN (event_value::jsonb -> 'metadata' ->> 'name')::TEXT
	-- 	ELSE NULL
	-- END AS prd_name
,
	COUNT(
		CASE
			WHEN LOWER(event_name) = 'view_product' THEN 1
			ELSE NULL
		END
	) AS pdp_pv_app,
	COUNT(
		DISTINCT CASE
			WHEN LOWER(event_name) = 'view_product' THEN appsflyer_id
			ELSE NULL
		END
	) AS pdp_uv_app_af_id_base,
	COUNT(
		DISTINCT CASE
			WHEN LOWER(event_name) = 'view_product' THEN COALESCE(
				customer_user_id,
				idfv,
				advertising_id,
				appsflyer_id
			)
			ELSE NULL
		END
	) AS pdp_uv_app_mc_id_base
FROM
	t_dwd
WHERE
	1 = 1
	AND CASE
		WHEN event_value IS json THEN (event_value::jsonb -> 'metadata' ->> 'barcode')::DOUBLE PRECISION
		ELSE NULL
	END IN (4987176324283)
GROUP BY
	TO_CHAR(event_time, 'YYYY-MM-DD'),
	CASE
		WHEN event_value IS json THEN (event_value::jsonb -> 'metadata' ->> 'barcode')::DOUBLE PRECISION
		ELSE NULL
	END
	-- ,
	-- CASE
	-- 	WHEN event_value IS json THEN (event_value::jsonb -> 'metadata' ->> 'name')::TEXT
	-- 	ELSE NULL
	-- END
ORDER BY
	TO_CHAR(event_time, 'YYYY-MM-DD') ASC
;