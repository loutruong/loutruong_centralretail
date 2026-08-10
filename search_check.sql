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
    AND event_time >= '2026-07-20 00:00:00+07'
    AND LOWER(is_primary_attribution) = 'true'
    AND LOWER(event_name) IN ('searching')
;