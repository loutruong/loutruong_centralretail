WITH
	t_dwd_trn AS (
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
			AND (
				event_time BETWEEN '2025-09-16 00:00:00+07' AND '2025-09-16 23:59:59+07'
			)
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
			AND (
				event_time BETWEEN '2025-09-16 00:00:00+07' AND '2025-09-16 23:59:59+07'
			)
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
			AND (
				event_time BETWEEN '2025-09-16 00:00:00+07' AND '2025-09-16 23:59:59+07'
			)
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
			AND (
				event_time BETWEEN '2025-09-16 00:00:00+07' AND '2025-09-16 23:59:59+07'
			)
			AND LOWER(is_primary_attribution) = 'true'
	)
SELECT
	MAX(rn) OVER (
		PARTITION BY
			order_id
	) AS max_r,
	*
FROM
	(
		SELECT
			ROW_NUMBER() OVER (
				PARTITION BY
					order_id
				ORDER BY
					event_time ASC
			) AS rn,
			*
		FROM
			(
				SELECT
					(event_value::jsonb ->> 'af_order_id')::DOUBLE PRECISION AS order_id,
					CASE
						WHEN (
							(event_value::jsonb ->> 'af_order_id')::DOUBLE PRECISION BETWEEN 6454202 AND 6460507
						) THEN 1
						ELSE 0
					END AS order_id_in_range,
					*
				FROM
					t_dwd_trn
				WHERE
					1 = 1
					AND event_name IN ('af_purchase')
			)
	)
;

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
			-- AND (
			-- 	event_time BETWEEN '2025-09-16 00:00:00+07' AND '2025-09-16 23:59:59+07'
			-- )
			AND event_time >= '2025-10-22 00:00:00+07'
			AND LOWER(is_primary_attribution) = 'true'
			AND LOWER(event_name) IN ('af_purchase', 'af_purchase_api')
	)
SELECT
	TO_CHAR(event_time, 'YYYY-MM-DD') AS event_time,
	MIN(event_time)                   AS start_hour_record,
	event_name,
	event_source,
	COUNT(
		DISTINCT (event_value::jsonb ->> 'af_order_id')::DOUBLE PRECISION
	) AS ord_id
FROM
	t_dwd_trn
WHERE
	1 = 1
	AND event_name IN ('af_purchase_api')
GROUP BY
	1,
	3,
	4
;