-- Active: 1756983137726@@10.250.139.30@5432@bigc_tracking_db
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
				UNION ALL
				--<< Break point inAPP
				SELECT
					'and_event_organic' AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
				UNION ALL
				--<< Break point inAPP
				SELECT
					'ios_event_organic' AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
			)
		WHERE
			1 = 1
			AND event_time >= '2025-06-01 00:00:00+07'
			AND event_name IN ('af_purchase')
			AND LOWER(is_primary_attribution) = 'true'
	)
SELECT
	SUM(CAST(event_revenue AS FLOAT))
FROM
	(
		SELECT
			t1.*
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
					AND event_time >= '2025-09-01 00:00:00+07'
			) AS t2 ON COALESCE(
				t1.customer_user_id,
				t1.idfv,
				t1.advertising_id,
				t1.appsflyer_id
			) = COALESCE(
				t2.customer_user_id,
				t2.idfv,
				t2.advertising_id,
				t2.appsflyer_id
			)
		WHERE
			1 = 1
			AND COALESCE(
				t2.customer_user_id,
				t2.idfv,
				t2.advertising_id,
				t2.appsflyer_id
			) IS NULL
	)
WHERE
	1 = 1
	AND customer_user_id IS NULL
;