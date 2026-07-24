WITH
    t_dwd AS (
        SELECT
            *
        FROM
            bigc_tracking_db.bigc_tracking.in_app_event_non_organic_androids
        WHERE
            1 = 1
            AND event_time >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '12 month'
            AND event_time < TIMESTAMP '2026-07-23 00:00:00'
            AND LOWER(is_primary_attribution) = 'true'
            AND LOWER(event_name) IN ('af_purchase_api', 'af_purchase')
        UNION ALL
        SELECT
            *
        FROM
            bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
        WHERE
            1 = 1
            AND event_time >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '12 month'
            AND event_time < TIMESTAMP '2026-07-23 00:00:00'
            AND LOWER(is_primary_attribution) = 'true'
            AND LOWER(event_name) IN ('af_purchase_api', 'af_purchase')
        UNION ALL
        SELECT
            *
        FROM
            bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
        WHERE
            1 = 1
            AND event_time >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '12 month'
            AND event_time < TIMESTAMP '2026-07-23 00:00:00'
            AND LOWER(is_primary_attribution) = 'true'
            AND LOWER(event_name) IN ('af_purchase_api', 'af_purchase')
        UNION ALL
        SELECT
            *
        FROM
            bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
        WHERE
            1 = 1
            AND event_time >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '12 month'
            AND event_time < TIMESTAMP '2026-07-23 00:00:00'
            AND LOWER(is_primary_attribution) = 'true'
            AND LOWER(event_name) IN ('af_purchase_api', 'af_purchase')
    ),
    t_user AS (
        SELECT
            COALESCE(NULLIF(customer_user_id, ''), NULLIF(idfv, ''), NULLIF(advertising_id, ''), NULLIF(appsflyer_id, '')) AS user_id,
            MAX(event_time)                                                                                                AS last_purchase_date
        FROM
            t_dwd
        GROUP BY
            1
    )
SELECT
    COUNT(*) AS l12m,
    COUNT(
        CASE
            WHEN last_purchase_date >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '9 month' THEN 1
        END
    ) AS l9m,
    COUNT(
        CASE
            WHEN last_purchase_date >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '6 month' THEN 1
        END
    ) AS l6m,
    COUNT(
        CASE
            WHEN last_purchase_date >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '3 month' THEN 1
        END
    ) AS l3m,
    COUNT(
        CASE
            WHEN last_purchase_date >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '1 month' THEN 1
        END
    ) AS l1m,
    COUNT(
        CASE
            WHEN last_purchase_date >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '15 day' THEN 1
        END
    ) AS l15d,
    COUNT(
        CASE
            WHEN last_purchase_date >= TIMESTAMP '2026-07-23 00:00:00' - INTERVAL '7 day' THEN 1
        END
    ) AS l7d
FROM
    t_user
;