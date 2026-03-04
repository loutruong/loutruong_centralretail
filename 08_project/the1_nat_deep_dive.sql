WITH
	t_dwd AS (
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
			) AS combined_events
		WHERE
			1 = 1
			AND (event_time BETWEEN '2025-11-03 00:00:00+07' AND '2025-11-03 23:59:59+07')
			AND LOWER(event_name) IN ('load_page_complete_profile', 'af_purchase', 'af_purchase_api')
			AND is_primary_attribution = 'true'
	)
SELECT
	-- 1. Extract the 'voucher_id' from the voucher_item object (which is a single voucher)
	CAST(voucher_item ->> 'voucher_id' AS FLOAT) AS voucher_id,
	CAST(t2.event_value::jsonb ->> 'store_id' AS INTEGER) AS store_id_integer,
	t2.*
FROM
	(
		SELECT
			*
		FROM
			t_dwd
		WHERE
			event_name = 'load_page_complete_profile'
	) AS t1
	LEFT JOIN (
		SELECT
			'load_page_complete_profile' AS event_name_fix,
			*
		FROM
			t_dwd
		WHERE
			event_name IN ('af_purchase', 'af_purchase_api')
	) AS t2 ON TO_CHAR(t1.event_time, 'YYYY-MM-DD') = TO_CHAR(t2.event_time, 'YYYY-MM-DD')
	AND COALESCE(t1.customer_user_id, t1.idfv, t1.advertising_id, t1.appsflyer_id) = COALESCE(t2.customer_user_id, t2.idfv, t2.advertising_id, t2.appsflyer_id)
	AND t1.event_name = t2.event_name_fix
	LEFT JOIN LATERAL JSONB_ARRAY_ELEMENTS(
		CASE
			WHEN t2.event_value IS NOT NULL
			AND (t2.event_value::jsonb -> 'af_voucher') IS NOT NULL
			AND JSONB_TYPEOF(t2.event_value::jsonb -> 'af_voucher') = 'array' THEN t2.event_value::jsonb -> 'af_voucher'
			ELSE '[]'::JSONB
		END
	) AS voucher_item ON TRUE
WHERE
	COALESCE(t2.customer_user_id, t2.idfv, t2.advertising_id, t2.appsflyer_id) IS NOT NULL
;