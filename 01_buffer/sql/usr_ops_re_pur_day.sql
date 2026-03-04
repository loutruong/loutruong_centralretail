with
    t_dwd as (
        select 'non_organic' as table_name, *
        from bigc_tracking_db.bigc_tracking.in_app_event_non_organic_androids
        where
            1 = 1
            and lower(is_primary_attribution) = 'true'
        union all --<< Break point
        select 'non_organic' as table_name, *
        from bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
        where
            1 = 1
            and lower(is_primary_attribution) = 'true'
        union all --<< Break point
        select 'organic' as table_name, *
        from bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
        where
            1 = 1
            and lower(is_primary_attribution) = 'true'
        union all --<< Break point
        select 'organic' as table_name, *
        from bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
        where
            1 = 1
            and lower(is_primary_attribution) = 'true'
        union all --<< Break point
        select 'install_non_organic' as table_name, *
        from bigc_tracking_db.bigc_tracking.install_non_organic_androids
        where
            1 = 1
            and lower(is_primary_attribution) = 'true'
        union all --<< Break point
        select 'install_non_organic' as table_name, *
        from bigc_tracking_db.bigc_tracking.install_non_organic_ios
        where
            1 = 1
            and lower(is_primary_attribution) = 'true'
        union all --<< Break point
        select 'install_organic' as table_name, *
        from bigc_tracking_db.bigc_tracking.install_organic_androids
        where
            1 = 1
            and lower(is_primary_attribution) = 'true'
        union all --<< Break point
        select 'install_organic' as table_name, *
        from bigc_tracking_db.bigc_tracking.install_organic_ios
        where
            1 = 1
            and lower(is_primary_attribution) = 'true'
    ),
    t_dws as (
        select CAST(
                event_value::jsonb ->> 'af_order_id' as FLOAT
            ) as order_id, *
        from t_dwd
    )
select
    event_time as order_created_time,
    customer_user_id,
    order_id
from t_dws
WHERE
    1 = 1
    and event_time >= '2025-07-01 00:00:00+07'
    and event_name in ('af_purchase')
LIMIT 10;