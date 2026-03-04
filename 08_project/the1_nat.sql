-- Active: 1757065616767@@10.250.139.30@5432@bigc_tracking_db
WITH
	t_dwd AS (
		SELECT
			CASE
				WHEN store IN (
					'govap',
					'anlac',
					'tanhiep',
					'truongchinh',
					'dian',
					'dongnai',
					'binhduong',
					'phuthanh'
				) THEN 'hcm'
				WHEN store IN (
					'miendong',
					'nguyenthithap',
					'cantho',
					'bentre',
					'travinh',
					'mytho',
					'baria',
					'baclieu'
				) THEN 'south'
				WHEN store IN (
					'danang',
					'dalat',
					'hue',
					'buonmathuot',
					'buonmethuot',
					'nhatrang',
					'vinh',
					'quynhon',
					'quangngai',
					'ninhthuan'
				) THEN 'central'
				WHEN store IN (
					'thanglong',
					'vinhphuc',
					'longbien',
					'thainguyen',
					'viettri',
					'melinh',
					'bacgiang',
					'laocai',
					'yenbai',
					'hanam'
				) THEN 'hn'
				WHEN store IN (
					'haiphong',
					'halong',
					'thanhhoa',
					'namdinh',
					'haiduong',
					'ninhbinh',
					'thaibinh',
					'hungyen'
				) THEN 'north'
				ELSE '99_others_region'
			END AS go_region,
			*
		FROM
			(
				SELECT
					CASE
						WHEN (
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
						END = 0 THEN 'qr_guided'
						ELSE '99_others_guided'
					END AS go_channel,
					CASE
						WHEN (
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
						END = 0 THEN CASE
							WHEN LOWER(SPLIT_PART(campaign, '_', 3)) IN ('bmt', 'buonmethuot') THEN 'buonmethuot'
							WHEN LOWER(SPLIT_PART(campaign, '_', 3)) LIKE 'go%'
							AND LENGTH(SUBSTR(LOWER(SPLIT_PART(campaign, '_', 3)), 3)) > 3 THEN SUBSTR(LOWER(SPLIT_PART(campaign, '_', 3)), 3)
							WHEN LOWER(SPLIT_PART(campaign, '_', 3)) IN ('all') THEN 'qrgeneral'
							ELSE LOWER(SPLIT_PART(campaign, '_', 3))
						END
						ELSE '99_others_store'
					END AS store,
					*
				FROM
					(
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
							-- AND event_time >= CURRENT_DATE - INTERVAL '1 day' --<< Controller
							AND event_time >= '2025-10-27 00:00:00+07' --<< Controller
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
							-- AND event_time >= CURRENT_DATE - INTERVAL '1 day' --<< Controller
							AND event_time >= '2025-10-27 00:00:00+07' --<< Controller
							AND is_primary_attribution = 'true'
							AND LOWER(event_name) IN (
								'load_page_complete_profile',
								'af_purchase',
								'af_purchase_api'
							)
					)
			)
	)
SELECT
	TO_CHAR(t1.event_time, 'YYYY-MM-DD')      AS ds,
	COALESCE(t1.go_channel, '00_All_Channel') AS channel,
	COALESCE(t1.go_region, '00_All_Region')   AS region,
	COALESCE(t1.store, '00_All_Store')        AS store,
	COUNT(
		DISTINCT CASE
			WHEN LOWER(t1.event_name) = 'install' THEN t1.appsflyer_id
			ELSE NULL
		END
	) AS install_cnt,
	COUNT(
		DISTINCT CASE
			WHEN LOWER(t1.event_name) IN ('load_page_complete_profile') THEN t1.appsflyer_id
			ELSE NULL
		END
	) AS reg,
	COUNT(
		DISTINCT CASE
			WHEN LOWER(t1.event_name) IN ('af_purchase', 'af_purchase_api') THEN COALESCE(
				t1.customer_user_id,
				t1.idfv,
				t1.advertising_id,
				t1.appsflyer_id
			)
			ELSE NULL
		END
	) AS byr_cnt,
	COUNT(
		DISTINCT COALESCE(
			t2.customer_user_id,
			t2.idfv,
			t2.advertising_id,
			t2.appsflyer_id
		)
	) AS new_byr_cnt
FROM
	(
		SELECT
			*
		FROM
			t_dwd
	) AS t1
	LEFT JOIN (
		SELECT
			'load_page_complete_profile' AS event_name_fix,
			*
		FROM
			t_dwd
		WHERE
			1 = 1
			AND event_name IN ('af_purchase', 'af_purchase_api')
	) AS t2 ON TO_CHAR(t1.event_time, 'YYYY-MM-DD') = TO_CHAR(t2.event_time, 'YYYY-MM-DD')
	AND COALESCE(
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
	AND t1.event_name = t2.event_name_fix
GROUP BY
	TO_CHAR(t1.event_time, 'YYYY-MM-DD'),
	CUBE (t1.go_channel, t1.go_region, t1.store)
ORDER BY
	TO_CHAR(t1.event_time, 'YYYY-MM-DD'),
	t1.go_channel DESC,
	t1.go_region DESC,
	t1.store DESC
;