--SELECT
--	*
--FROM
--	(
--		SELECT
--			*,
--			ROW_NUMBER() OVER (
--				PARTITION BY
--					mm
--				ORDER BY
--					search_volume DESC
--			) AS rn
--		FROM
--			(
--				SELECT
--					TO_CHAR(event_time, 'YYYY-MM') AS mm,
--					CASE
--						WHEN event_value IS JSON THEN (event_value::jsonb ->> 'af_search_string')
--						ELSE 'Unknown'
--					END AS search_term,
--					COUNT(*) AS search_volume
--				FROM
--					(
--						SELECT
--							*
--						FROM
--							bigc_tracking_db.bigc_tracking.in_app_event_non_organic_androids
--						UNION ALL
--						SELECT
--							*
--						FROM
--							bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
--						UNION ALL
--						SELECT
--							*
--						FROM
--							bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
--						UNION ALL
--						SELECT
--							*
--						FROM
--							bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
--					)
--				WHERE
--					1 = 1
--					AND (event_time BETWEEN '2025-11-01 00:00:00+07' AND '2025-11-30 23:59:59+07')
--					AND LOWER(is_primary_attribution) = 'true'
--					AND LOWER(event_name) IN ('af_search')
--				GROUP BY
--					CASE
--						WHEN event_value IS JSON THEN (event_value::jsonb ->> 'af_search_string')
--						ELSE NULL
--					END,
--					TO_CHAR(event_time, 'YYYY-MM')
--				ORDER BY
--					TO_CHAR(event_time, 'YYYY-MM'),
--					COUNT(*) DESC
--			)
--	)
--WHERE
--	1 = 1
--	AND rn <= 50
--;
WITH
	t_dwd AS (
		SELECT
			TO_CHAR(event_time, 'YYYY-MM') AS mm,
			CASE
				WHEN event_value IS JSON THEN (event_value::jsonb ->> 'af_search_string')
				ELSE NULL
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
			(event_time BETWEEN '2025-08-01 00:00:00+07' AND '2025-08-31 23:59:59+07')
			AND LOWER(is_primary_attribution) = 'true'
			AND LOWER(event_name) IN ('af_search')
		GROUP BY
			CASE
				WHEN event_value IS JSON THEN (event_value::jsonb ->> 'af_search_string')
				ELSE NULL
			END,
			TO_CHAR(event_time, 'YYYY-MM')
	),
	t_median AS (
		SELECT
			mm,
			PERCENTILE_CONT(0.5) WITHIN GROUP (
				ORDER BY
					search_volume
			) AS median_search_volume
		FROM
			t_dwd
		GROUP BY
			mm
	)
SELECT
	t1.mm,
	t1.search_term,
	t1.search_volume,
	t2.median_search_volume,
	CASE
		WHEN t1.search_volume >= t2.median_search_volume THEN 'Above Median'
		ELSE 'Below Median'
	END AS search_volume_label
FROM
	(
		SELECT
			*
		FROM
			t_dwd
	) AS t1
	LEFT JOIN (
		SELECT
			*
		FROM
			t_median
	) AS t2 ON t1.mm = t2.mm
WHERE
	t1.search_term IS NOT NULL
ORDER BY
	t1.mm,
	t1.search_volume DESC
;