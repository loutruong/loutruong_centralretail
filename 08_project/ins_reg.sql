WITH
	dim_filter AS (
		SELECT
			'2025-10-27 00:00:00+07'::TIMESTAMP AS start_time
	),
	t_dwd_install AS (
		SELECT
			CASE
				WHEN LOWER(SPLIT_PART(campaign, '_', 3)) IN ('bmt', 'buonmethuot') THEN 'buonmethuot'
				WHEN LOWER(SPLIT_PART(campaign, '_', 3)) LIKE 'go%'
				AND LENGTH(SUBSTR(LOWER(SPLIT_PART(campaign, '_', 3)), 3)) > 3 THEN SUBSTR(LOWER(SPLIT_PART(campaign, '_', 3)), 3)
				ELSE LOWER(SPLIT_PART(campaign, '_', 3))
			END AS store,
			*
		FROM
			(
				SELECT
					*
				FROM
					bigc_tracking_db.bigc_tracking.install_non_organic_androids
				UNION ALL
				SELECT
					*
				FROM
					bigc_tracking_db.bigc_tracking.install_non_organic_ios
				UNION ALL
				SELECT
					*
				FROM
					bigc_tracking_db.bigc_tracking.install_organic_androids
				UNION ALL
				SELECT
					*
				FROM
					bigc_tracking_db.bigc_tracking.install_organic_ios
			)
		WHERE
			1 = 1
			AND event_time >= (
				SELECT
					start_time
				FROM
					dim_filter
			)
			AND LOWER(event_name) IN ('install')
			AND (
				media_source LIKE 'qr_go_%'
				OR media_source LIKE 'Store_%'
			)
			AND (
				campaign LIKE 'qr_go_%'
				OR campaign LIKE 'AppInstall_Store_%'
			)
			AND CASE
				WHEN SPLIT_PART(campaign, '_', 3) LIKE 'go%'
				AND campaign LIKE 'AppInstall_Store_%' THEN 1
				ELSE 0
			END = 0
	),
	t_dwd_reg AS (
		SELECT
			CASE
				WHEN LOWER(SPLIT_PART(campaign, '_', 3)) IN ('bmt', 'buonmethuot') THEN 'buonmethuot'
				WHEN LOWER(SPLIT_PART(campaign, '_', 3)) LIKE 'go%'
				AND LENGTH(SUBSTR(LOWER(SPLIT_PART(campaign, '_', 3)), 3)) > 3 THEN SUBSTR(LOWER(SPLIT_PART(campaign, '_', 3)), 3)
				ELSE LOWER(SPLIT_PART(campaign, '_', 3))
			END AS store,
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
			AND event_time >= (
				SELECT
					start_time
				FROM
					dim_filter
			)
			AND LOWER(event_name) IN ('load_page_complete_profile')
			AND is_primary_attribution = 'true'
			AND (
				media_source LIKE 'qr_go_%'
				OR media_source LIKE 'Store_%'
			)
			AND (
				campaign LIKE 'qr_go_%'
				OR campaign LIKE 'AppInstall_Store_%'
			)
			AND CASE
				WHEN SPLIT_PART(campaign, '_', 3) LIKE 'go%'
				AND campaign LIKE 'AppInstall_Store_%' THEN 1
				ELSE 0
			END = 0
	)
SELECT
	ds,
	store,
	'QR Scan to install and register' AS campaign_type,
	SUM(COALESCE(install_cnt, 0))     AS install_cnt,
	SUM(COALESCE(reg, 0))             AS reg
FROM
	(
		SELECT
			TO_CHAR(event_time, 'YYYY-MM-DD') AS ds,
			store,
			COUNT(DISTINCT appsflyer_id)      AS install_cnt,
			NULL                              AS reg
		FROM
			t_dwd_install
		GROUP BY
			TO_CHAR(event_time, 'YYYY-MM-DD'),
			store
		UNION ALL
		SELECT
			TO_CHAR(event_time, 'YYYY-MM-DD') AS ds,
			store,
			NULL                              AS install_cnt,
			COUNT(DISTINCT appsflyer_id)      AS reg
		FROM
			t_dwd_reg
		GROUP BY
			TO_CHAR(event_time, 'YYYY-MM-DD'),
			store
	)
GROUP BY
	ds,
	store
ORDER BY
	ds,
	store
;