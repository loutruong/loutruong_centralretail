-- Active: 1757065616767@@10.250.139.30@5432@bigc_tracking_db
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
		UNION ALL
		--<< Break point
		SELECT
			CASE
				WHEN LOWER(is_retargeting) IN ('true') THEN 'and_install_non_organic_retargeting'
				ELSE 'and_install_non_organic'
			END AS table_name,
			*
		FROM
			bigc_tracking_db.bigc_tracking.install_non_organic_androids
		UNION ALL
		--<< Break point Install
		SELECT
			CASE
				WHEN LOWER(is_retargeting) IN ('true') THEN 'ios_install_non_organic_retargeting'
				ELSE 'ios_install_non_organic'
			END AS table_name,
			*
		FROM
			bigc_tracking_db.bigc_tracking.install_non_organic_ios
		UNION ALL
		--<< Break point Install
		SELECT
			'and_install_organic' AS table_name,
			*
		FROM
			bigc_tracking_db.bigc_tracking.install_organic_androids
		UNION ALL
		--<< Break point Install
		SELECT
			'ios_install_organic' AS table_name,
			*
		FROM
			bigc_tracking_db.bigc_tracking.install_organic_ios
	)
WHERE
	1 = 1 --
	-- and event_time = '2025-09-08 00:00:00+07' --<< Snapshot date
	AND event_time >= '2026-01-26 00:00:00+07' --<< Rolling date specific date base
	-- and event_time BETWEEN '2025-09-08 00:00:00+07' and '2025-09-08 00:00:59+07' --<< Specific range
	-- and event_time BETWEEN '2025-09-08 00:00:00+07' and CURRENT_DATE  - INTERVAL '1 second' --<< Specific range to lastest
	-- AND (
	-- 	event_time BETWEEN CURRENT_DATE - INTERVAL '1 day' AND CURRENT_DATE  - INTERVAL '1 second'
	-- ) --<< Specific range
	-- and event_time = CURRENT_DATE - INTERVAL '1 day' --<< Rolling date D0 base
	-- and event_time >= CURRENT_DATE - INTERVAL '1 day' --<< Rolling date D0 base
	-- AND LOWER(event_name) IN ('game_1') --<< Event filter
	AND customer_user_id IN ('0986234960')
	AND LOWER(is_primary_attribution) = 'true'
;