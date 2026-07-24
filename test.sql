-- Active: 1757065616767@@10.250.139.30@5432@bigc_tracking_db
WITH
    base AS (
        SELECT
            TO_CHAR(event_time, 'YYYY-MM-DD')                          AS ds,
            media_source,
            campaign,
            adset,
            ad,
            channel,
            event_value,
            (event_value::jsonb) ->> 'store_id'                        AS store_id,
            (event_value::jsonb) ->> 'af_order_id'                     AS af_order_id,
            (event_value::jsonb) ->> 'af_receipt_id'                   AS af_receipt_id,
            ((event_value::jsonb) ->> 'af_discount')::NUMERIC          AS af_discount,
            ((event_value::jsonb) ->> 'af_price')::NUMERIC             AS af_price,
            ((event_value::jsonb) ->> 'af_revenue')::NUMERIC           AS af_revenue,
            ((event_value::jsonb) ->> 'af_shipping_fee')::NUMERIC      AS af_shipping_fee,
            (event_value::jsonb) ->> 'af_payment_type'                 AS af_payment_type,
            (event_value::jsonb) ->> 'af_currency'                     AS af_currency,
            ((event_value::jsonb) ->> 'af_new_member')::INT            AS af_new_member,
            ((event_value::jsonb) ->> 'af_is_first_purchase')::BOOLEAN AS af_is_first_purchase,
            (event_value::jsonb) ->> 'af_content_type'                 AS af_content_type,
            ((event_value::jsonb) ->> 'af_shipping_type')::INT         AS af_shipping_type,
            ((event_value::jsonb) ->> 'af_point')::INT                 AS af_point,
            LOWER(REPLACE(media_source, ' ', ''))                      AS ms,
            LOWER(REPLACE(campaign, ' ', ''))                          AS cp
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
                UNION ALL
                SELECT
                    CASE
                        WHEN LOWER(is_retargeting) IN ('true') THEN 'ios_event_non_organic_retargeting'
                        ELSE 'ios_event_non_organic'
                    END AS table_name,
                    *
                FROM
                    bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
                UNION ALL
                SELECT
                    'and_event_organic' AS table_name,
                    *
                FROM
                    bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
                UNION ALL
                SELECT
                    'ios_event_organic' AS table_name,
                    *
                FROM
                    bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
            ) src
        WHERE
            1 = 1
            AND event_time >= '2026-07-02 00:00:00+07'
            AND LOWER(is_primary_attribution) = 'true'
            AND LOWER(event_name) IN ('af_purchase_api', 'af_purchase')
    ),
    op AS (
        SELECT
            base.*,
            CASE
                WHEN media_source IS NULL
                OR media_source = '' THEN NULL
                WHEN STRPOS(ms, 'applesearch') > 0 THEN 'Paid Apple Search'
                WHEN STRPOS(ms, 'moengage') > 0 THEN 'MoE'
                WHEN STRPOS(ms, 'google') > 0 THEN 'Paid Google - App'
                WHEN STRPOS(ms, 'zns') > 0 THEN 'ZnS'
                WHEN STRPOS(ms, 'sms') > 0 THEN 'SmS'
                WHEN STRPOS(ms, 'criteo') > 0 THEN 'Paid Criteo'
                WHEN STRPOS(ms, 'cgo_facebook') > 0
                OR STRPOS(ms, 'facebook_int') > 0
                OR (
                    STRPOS(ms, 'facebookads') > 0
                    AND (
                        STRPOS(cp, 'ct:') > 0
                        OR STRPOS(cp, '|pl') > 0
                        OR cp = 'none'
                        OR STRPOS(cp, 'cgo') > 0
                    )
                )
                OR (
                    STRPOS(ms, 'sku') > 0
                    AND cp IN ('allproduct_detail', 'awo_allproduct', 'product_detail', 'none', 'mooncake_product_detail')
                ) THEN 'Paid Facebook - App'
                WHEN STRPOS(ms, 'ulv') > 0
                OR STRPOS(ms, 'facebookads') > 0
                OR STRPOS(ms, 'sku') > 0 THEN 'Paid Other'
                ELSE 'Organic'
            END AS operation
        FROM
            base
    ),
    chan AS (
        SELECT
            op.*,
            CASE
                WHEN operation IS NULL THEN NULL
                WHEN STRPOS(operation, 'Livestream') > 0
                OR STRPOS(operation, 'Promote') > 0
                OR STRPOS(operation, 'Facebook') > 0 THEN 'Paid Facebook'
                WHEN STRPOS(operation, 'Web SEM') > 0
                OR STRPOS(operation, 'Google') > 0 THEN 'Paid Google'
                WHEN STRPOS(operation, 'Criteo') > 0 THEN 'Paid Criteo'
                WHEN STRPOS(operation, 'Apple') > 0 THEN 'Paid Apple Search'
                WHEN STRPOS(operation, 'MoE') > 0 THEN 'MoE'
                WHEN STRPOS(operation, 'ZnS') > 0 THEN 'ZnS'
                WHEN STRPOS(operation, 'SmS') > 0 THEN 'SmS'
                WHEN STRPOS(operation, 'Other') > 0 THEN 'Paid Other'
                WHEN STRPOS(operation, 'Organic') > 0 THEN 'Organic'
                ELSE 'Organic'
            END AS channel_group,
            CASE
                WHEN operation IS NULL THEN NULL
                WHEN STRPOS(operation, 'MoE') > 0
                OR STRPOS(operation, 'ZnS') > 0
                OR STRPOS(operation, 'SmS') > 0 THEN 'Paid crm - Total'
                WHEN STRPOS(operation, 'Facebook - App') > 0
                OR STRPOS(operation, 'Criteo') > 0
                OR STRPOS(operation, 'Google - App') > 0
                OR STRPOS(operation, 'Apple Search') > 0 THEN 'Paid Ads - App'
                WHEN STRPOS(operation, 'Livestream') > 0
                OR STRPOS(operation, 'Promote') > 0 THEN 'Paid Ads - Promo + Live'
                WHEN STRPOS(operation, 'Web SEM') > 0 THEN 'Paid Ads - Web'
                WHEN STRPOS(operation, 'Paid Other') > 0 THEN 'Paid Other'
                WHEN STRPOS(operation, 'Ogarnic') > 0
                OR STRPOS(operation, 'Organic') > 0 THEN 'Organic'
                ELSE 'Organic'
            END AS sources
        FROM
            op
    )
SELECT
    ds,
    media_source,
    campaign,
    adset,
    ad,
    channel,
    event_value,
    store_id,
    af_order_id,
    af_receipt_id,
    af_discount,
    af_price,
    af_revenue,
    af_shipping_fee,
    af_payment_type,
    af_currency,
    af_new_member,
    af_is_first_purchase,
    af_content_type,
    af_shipping_type,
    af_point,
    operation,
    channel_group,
    sources,
    CASE
        WHEN sources IS NULL THEN NULL
        WHEN sources = 'Paid Other'
        AND STRPOS(cp, 'pepsi') > 0 THEN 'Pepsi'
        WHEN sources = 'Paid Other'
        AND STRPOS(cp, 'unilever') = 0 THEN 'Unilever'
        ELSE ''
    END AS sub_brand
FROM
    chan
;

-- https://app.go-vietnam.vn/RUpb?af_xp=custom&pid=MoEngage_Notification&c=Test&is_retargeting=true&af_reengagement_window=1d&deep_link_sub1=campaign&deep_link_value=891&af_dp=govietnam%3A%2F%2F&af_sub1=campaign&af_click_lookback=1d&af_force_deeplink=true
SELECT
    *
FROM
    bigc_tracking_db.bigc_tracking.in_app_event_non_organic_androids
LIMIT
    10
;

SELECT
    *
FROM
    crv_data.loutruong_supplier_perf_di
WHERE
    1 = 1
    AND sale_date >= '14-JUL-2026'
    AND supplier_code IN (
        SELECT
            supplier_code
        FROM
            omni_digimgr.loutruong_dim_supplier
    )
ORDER BY
    sale_date ASC,
    supplier_code ASC,
    dimension_group ASC,
    dimension ASC
;

SELECT
    *
FROM
    crv_data.loutruong_supplier_byr_perf_di
WHERE
    1 = 1
    AND sale_date >= '14-JUL-2026'
    AND supplier_code IN (
        SELECT
            supplier_code
        FROM
            omni_digimgr.loutruong_dim_supplier
    )
ORDER BY
    sale_date ASC,
    supplier_code ASC
;

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
        UNION ALL
        SELECT
            CASE
                WHEN LOWER(is_retargeting) IN ('true') THEN 'ios_event_non_organic_retargeting'
                ELSE 'ios_event_non_organic'
            END AS table_name,
            *
        FROM
            bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
        UNION ALL
        SELECT
            'and_event_organic' AS table_name,
            *
        FROM
            bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
        UNION ALL
        SELECT
            'ios_event_organic' AS table_name,
            *
        FROM
            bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
    )
WHERE
    1 = 1
    AND event_time >= CURRENT_DATE - INTERVAL '1 day'
    AND LOWER(is_primary_attribution) = 'true'
    AND LOWER(event_name) IN ('af_search')
LIMIT
    10
;

WITH
    t_dwd AS (
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
                UNION ALL
                SELECT
                    CASE
                        WHEN LOWER(is_retargeting) IN ('true') THEN 'ios_event_non_organic_retargeting'
                        ELSE 'ios_event_non_organic'
                    END AS table_name,
                    *
                FROM
                    bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
                UNION ALL
                SELECT
                    'and_event_organic' AS table_name,
                    *
                FROM
                    bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
                UNION ALL
                SELECT
                    'ios_event_organic' AS table_name,
                    *
                FROM
                    bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
            )
        WHERE
            1 = 1
            AND event_time >= CURRENT_DATE - INTERVAL '1 day'
            AND LOWER(is_primary_attribution) = 'true'
    )
SELECT
    event_name,
    COUNT(*)   AS ROWS
FROM
    t_dwd
GROUP BY
    event_name
ORDER BY
    COUNT(*) DESC
;

SELECT
    *
FROM
    (
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
                UNION ALL
                SELECT
                    CASE
                        WHEN LOWER(is_retargeting) IN ('true') THEN 'ios_event_non_organic_retargeting'
                        ELSE 'ios_event_non_organic'
                    END AS table_name,
                    *
                FROM
                    bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
                UNION ALL
                SELECT
                    'and_event_organic' AS table_name,
                    *
                FROM
                    bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
                UNION ALL
                SELECT
                    'ios_event_organic' AS table_name,
                    *
                FROM
                    bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
            )
        WHERE
            1 = 1
            AND event_time >= CURRENT_DATE - INTERVAL '1 day'
            AND LOWER(is_primary_attribution) = 'true'
    )
ORDER BY
    event_time ASC
LIMIT
    100
;