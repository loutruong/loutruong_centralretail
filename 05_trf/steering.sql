WITH
	t_dwd AS (
		SELECT
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
			AND event_time >= '2025-11-16 00:00:00+07' --<< Controller
			AND LOWER(event_name) IN ('install')
		UNION ALL
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
			AND event_time >= '2025-11-16 00:00:00+07' --<< Controller
			AND LOWER(event_name) IN ('af_purchase', 'af_purchase_api')
			AND is_primary_attribution = 'true'
	)
SELECT
	*
FROM
	t_dwd
;