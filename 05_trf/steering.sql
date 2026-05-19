-- Active: 1757065616767@@10.250.139.30@5432@bigc_tracking_db
WITH
	t_dwd AS (
		-- SELECT
		-- 	*
		-- FROM
		-- 	(
		-- 		SELECT
		-- 			*
		-- 		FROM
		-- 			bigc_tracking_db.bigc_tracking.install_non_organic_androids
		-- 		UNION ALL
		-- 		SELECT
		-- 			*
		-- 		FROM
		-- 			bigc_tracking_db.bigc_tracking.install_non_organic_ios
		-- 		UNION ALL
		-- 		SELECT
		-- 			*
		-- 		FROM
		-- 			bigc_tracking_db.bigc_tracking.install_organic_androids
		-- 		UNION ALL
		-- 		SELECT
		-- 			*
		-- 		FROM
		-- 			bigc_tracking_db.bigc_tracking.install_organic_ios
		-- 	)
		-- WHERE
		-- 	1 = 1
		-- 	AND event_time >= '2026-05-15 00:00:00+07' --<< Controller
		-- 	AND LOWER(event_name) IN ('install')
		-- UNION ALL
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
			AND event_time >= '2026-05-15 00:00:00+07' --<< Controller
			-- AND LOWER(event_name) IN ('af_purchase', 'af_purchase_api')
			AND LOWER(event_name) IN ('view_my_wallet')
			AND is_primary_attribution = 'true'
	)
SELECT
	*
FROM
	t_dwd
;

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
	AND event_time >= '2026-05-16 00:00:00+07' --<< Controller
	-- AND LOWER(event_name) IN ('af_purchase', 'af_purchase_api')
	-- AND LOWER(event_name) IN ('view_my_wallet')
	AND LOWER(event_name) LIKE '%view%my%wallet%'
	-- AND is_primary_attribution = 'true'
;