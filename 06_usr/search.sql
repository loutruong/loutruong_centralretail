SELECT
	*
FROM
	(
		SELECT
			*,
			ROW_NUMBER() OVER (
				PARTITION BY
					mm
				ORDER BY
					search_volume DESC
			) AS rn
		FROM
			(
				SELECT
					TO_CHAR(event_time, 'YYYY-MM') AS mm,
					CASE
						WHEN event_value IS JSON THEN (event_value::jsonb ->> 'af_search_string')
						ELSE 'Unknown'
					END AS search_term,
					COUNT(*) AS search_volume
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
					AND (event_time BETWEEN '2025-11-01 00:00:00+07' AND '2025-11-30 23:59:59+07')
					AND LOWER(is_primary_attribution) = 'true'
					AND LOWER(event_name) IN ('af_search')
				GROUP BY
					CASE
						WHEN event_value IS JSON THEN (event_value::jsonb ->> 'af_search_string')
						ELSE 'Unknown'
					END,
					TO_CHAR(event_time, 'YYYY-MM')
				ORDER BY
					TO_CHAR(event_time, 'YYYY-MM'),
					COUNT(*) DESC
			)
	)
WHERE
	1 = 1
	AND rn <= 50
;