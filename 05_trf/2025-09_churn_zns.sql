-- Active: 1757065616767@@10.250.139.30@5432@bigc_tracking_db
WITH
	t_dwd_trn AS (
		SELECT
			*
		FROM
			(
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
				UNION ALL --<< Break point inAPP
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
				UNION ALL --<< Break point inAPP
				SELECT
					'and_event_organic' AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
				WHERE
					1 = 1
					AND LOWER(is_primary_attribution) = 'true'
				UNION ALL --<< Break point inAPP
				SELECT
					'ios_event_organic' AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
				WHERE
					1 = 1
					AND LOWER(is_primary_attribution) = 'true'
			)
		WHERE
			1 = 1
			AND event_time >= '2025-05-01 00:00:00+07'
			AND event_name IN ('af_purchase')
	)
SELECT
	*
	--   STRING_AGG(mm, ',') AS duration,
	--   phone_number,
	--   COUNT(DISTINCT mm) AS active_months,
	--   AVG(app_ord_cnt) AS app_ord_cnt,
	--   AVG(app_gmv) AS app_gmv,
	--   COALESCE(AVG(app_gmv) / AVG(app_ord_cnt), 0) AS app_aov,
	--   ROW_NUMBER() OVER (
	--     ORDER BY
	--       COALESCE(AVG(app_gmv) / AVG(app_ord_cnt), 0) DESC
	--   ) AS rn
FROM
	(
		SELECT
			TO_CHAR(t1.event_time, 'yyyy-mm') AS mm,
			t1.customer_user_id               AS phone_number,
			COUNT(
				DISTINCT (t1.event_value::jsonb ->> 'af_order_id')::DOUBLE PRECISION
			) AS app_ord_cnt,
			SUM(
				(t1.event_value::jsonb ->> 'af_revenue')::DOUBLE PRECISION
			) AS app_gmv
		FROM
			(
				SELECT
					*
				FROM
					t_dwd_trn
			) AS t1
			LEFT JOIN (
				SELECT
					*
				FROM
					t_dwd_trn
				WHERE
					1 = 1
					AND event_time >= '2025-08-01 00:00:00+07'
			) AS t2 ON t1.appsflyer_id = t2.appsflyer_id
		WHERE
			1 = 1
			AND t2.appsflyer_id IS NULL
			AND t1.customer_user_id IS NOT NULL
		GROUP BY
			1,
			2
	)
WHERE
	1 = 1
	AND phone_number IN ('0868638782')
;