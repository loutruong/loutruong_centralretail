SELECT
    t1.*,
    COALESCE(t2.total_event, 0) AS total_event
FROM
    (
        SELECT
            UNNEST(ARRAY['view_the1_dedicated_screen', 'click_the1_dedicated_icon', 'view_the1_campaign_list', 'click_the1_campaign_opt_in', 'view_the1_campaign_no_opt_in_list', 'view_the1_campaign_no_opt_in_detail', 'view_the1_campaign_history_list', 'view_the1_campaign_history_detail', 'view_the1_campaign_detail']) AS event_name
    ) AS t1
    LEFT JOIN (
        SELECT
            event_name,
            COUNT(*)   AS total_event
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
            AND event_time >= '2025-11-01 00:00:00+07'
            AND LOWER(is_primary_attribution) = 'true'
            AND event_name IN ('view_the1_dedicated_screen', 'click_the1_dedicated_icon', 'view_the1_campaign_list', 'click_the1_campaign_opt_in', 'view_the1_campaign_no_opt_in_list', 'view_the1_campaign_no_opt_in_detail', 'view_the1_campaign_history_list', 'view_the1_campaign_history_detail', 'view_the1_campaign_detail', 'view_the1_campaign_detail', 'view_the1_campaign_detail', 'click_the1_campaign_opt_in')
        GROUP BY
            event_name
    ) AS t2 ON t1.event_name = t2.event_name
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
    AND event_time >= '2025-12-10 00:00:00+07'
    AND LOWER(is_primary_attribution) = 'true'
    AND event_name IN ('input_OTP')
    AND customer_user_id LIKE '%65200201%'
ORDER BY
    event_time DESC
;