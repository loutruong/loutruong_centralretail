-- Active: 1757065616767@@10.250.139.30@5432@bigc_tracking_db
WITH
	t_dwd AS (
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
				SELECT
					CASE
						WHEN LOWER(is_retargeting) IN ('true') THEN 'ios_event_non_organic_retargeting'
						ELSE 'ios_event_non_organic'
					END AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
				UNION ALL
				SELECT
					'and_event_organic' AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
				UNION ALL
				SELECT
					'ios_event_organic' AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
			)
		WHERE
			1 = 1 --
			-- AND event_time >= CURRENT_DATE - INTERVAL '10 day'
			AND (event_time BETWEEN '2026-01-01 00:00:00+07' AND '2026-02-15 23:59:59+07')
			-- AND event_time >= '2026-02-13 00:00:00+07'
			AND LOWER(is_primary_attribution) = 'true'
			AND event_name IN ('af_purchase_api', 'af_purchase')
	)
	-- ,
	-- t_mab AS (
	-- 	SELECT
	-- 		TO_CHAR(event_time, 'YYYY-MM')                                                 AS mm,
	-- 		COUNT(DISTINCT COALESCE(customer_user_id, idfv, advertising_id, appsflyer_id)) AS byr_cnt
	-- 	FROM
	-- 		t_dwd
	-- 	GROUP BY
	-- 		TO_CHAR(event_time, 'YYYY-MM')
	-- )
,
	t_dab AS (
		SELECT
			TO_CHAR(event_time, 'YYYY-MM-DD')                                                    AS ds,
			-- event_name                                                                     AS event_name,
			COUNT(DISTINCT COALESCE(customer_user_id, idfv, advertising_id, appsflyer_id))       AS byr_cnt,
			SUM(CAST(event_revenue_usd AS DOUBLE PRECISION))                                     AS net_sales
		FROM
			t_dwd
		GROUP BY
			TO_CHAR(event_time, 'YYYY-MM-DD')
			-- ,
			-- event_name
		ORDER BY
			TO_CHAR(event_time, 'YYYY-MM-DD') ASC
	)
SELECT
	*
FROM
	t_dab
	-- t_mab
;