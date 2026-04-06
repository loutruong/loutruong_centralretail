-- Active: 1757065616767@@10.250.139.30@5432@bigc_tracking_db
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
            )
        WHERE
            1 = 1
            AND event_time >= '2025-12-26 00:00:00+07'
            -- AND (event_time BETWEEN '2026-01-05 00:00:00+07' AND '2026-01-06 23:59:59+07')
            AND LOWER(is_primary_attribution) = 'true'
            AND LOWER(event_name) IN ('game_1_2026_start')
    )
SELECT
    TO_CHAR(event_time, 'yyyy-mm-dd')                                                                           AS event_date,
    -- COALESCE(event_value::json ->> 'sitecode', '00_all')                                 AS         store_id,
    '2) User visit page Hai Loc'                                                                                AS metric,
    -- COUNT(DISTINCT customer_user_id)                                               AS       usr_cnt,
    COUNT(DISTINCT COALESCE(customer_user_id, idfv, advertising_id, appsflyer_id))                              AS usr_cnt_all
FROM
    t_dwd
GROUP BY
    TO_CHAR(event_time, 'yyyy-mm-dd')
    --     ,
    --     CUBE (event_value::json ->> 'sitecode')
    -- ORDER BY
    --     -- COALESCE(event_value::json ->> 'sitecode', '00_all') ASC,
    --     COUNT(DISTINCT COALESCE(customer_user_id, idfv, advertising_id, appsflyer_id)) DESC
;

-- Pull raw data
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
            )
        WHERE
            1 = 1
            AND event_time >= '2025-12-26 00:00:00+07'
            -- AND (event_time BETWEEN '2025-12-23 00:00:00+07' AND '2025-12-23 23:59:59+07')
            AND LOWER(is_primary_attribution) = 'true'
            AND LOWER(event_name) IN ('game_1_2026_result')
            -- AND LOWER(event_name) IN ('game_1_2026_play')
    )
SELECT DISTINCT
    TO_CHAR(event_time, 'yyyy-mm-dd') AS ds,
    event_value::json ->> 'customer_id' AS mc_usr_id,
    event_value::json ->> 'card_no' AS card_no,
    CASE
        WHEN event_value::json ->> 'reward_value' IN ('10k') THEN '10k'
        WHEN event_value::json ->> 'reward_value' IN ('20k') THEN '20k'
        WHEN event_value::json ->> 'reward_value' IN ('50k') THEN '50k'
        WHEN event_value::json ->> 'reward_value' IN ('100k') THEN '100k'
        ELSE '0'
    END AS reward_value,
    event_value::json ->> 'sitecode' AS store_id
FROM
    t_dwd
WHERE
    1 = 1
    AND event_value::json ->> 'reward_type' = 'voucher'
;