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
            LOWER(is_primary_attribution) = 'true'
            AND event_name IN ('af_purchase', 'af_purchase_api')
            AND event_time >= '2026-02-10 00:00:00+07'
    )
SELECT
    t.*, -- This keeps all original columns
    items.value ->> 'id' AS content_product_id, -- Extracts the ID from the array
    items.value ->> 'quantity' AS content_quantity -- Optional: Extracts quantity too
FROM
    t_dwd t,
    LATERAL JSONB_ARRAY_ELEMENTS(t.event_value::jsonb -> 'af_content') AS items
WHERE
    (t.event_value::jsonb ->> 'af_order_id') IN ('7354101')
;