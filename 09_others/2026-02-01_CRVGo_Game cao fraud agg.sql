WITH
    t_dwd AS (
        SELECT
            FORMAT_DATE ('%Y-%m-%d', DATE (reward_time)) AS ds,
            *
        FROM
            loutruongdataplatform1.loutruong_dwd.loutruong_reward
        WHERE
            1 = 1
            AND reward_time IS NOT NULL
    )
SELECT
    data_range,
    COALESCE(abnormal_per_user_status, '00_all') AS abnormal_per_user_status,
    user_get_reward_cnt
FROM
    (
        SELECT
            CONCAT(MIN(ds), '->', MAX(ds))               AS data_range,
            COALESCE(abnormal_per_user_status, '00_all') AS abnormal_per_user_status,
            COUNT(DISTINCT the1_crd_no)                  AS user_get_reward_cnt
        FROM
            (
                SELECT
                    CASE
                        WHEN max_reward_time_per_user > 3 THEN '01_Yes'
                        ELSE '02_No'
                    END AS abnormal_per_user_status,
                    CASE
                        WHEN max_reward_time_one_day_per_user > 3 THEN '01_Yes'
                        ELSE '02_No'
                    END AS abnormal_per_day_per_user_status,
                    *
                FROM
                    (
                        SELECT
                            MAX(reward_time_one_day_per_user) OVER (
                                PARTITION BY
                                    the1_crd_no
                            ) AS max_reward_time_one_day_per_user,
                            MAX(reward_time_per_user) OVER (
                                PARTITION BY
                                    the1_crd_no
                            ) AS max_reward_time_per_user,
                            *
                        FROM
                            (
                                SELECT
                                    ROW_NUMBER() OVER (
                                        PARTITION BY
                                            ds,
                                            the1_crd_no
                                        ORDER BY
                                            ds,
                                            the1_crd_no
                                    ) AS reward_time_one_day_per_user,
                                    ROW_NUMBER() OVER (
                                        PARTITION BY
                                            the1_crd_no
                                        ORDER BY
                                            ds
                                    ) AS reward_time_per_user,
                                    *
                                FROM
                                    t_dwd
                            )
                    )
            )
        GROUP BY
            CUBE (abnormal_per_user_status)
    )
ORDER BY
    COALESCE(abnormal_per_user_status, '00_all')
;

WITH
    t_dwd AS (
        SELECT
            FORMAT_DATE ('%Y-%m-%d', DATE (reward_time)) AS ds,
            *
        FROM
            loutruongdataplatform1.loutruong_dwd.loutruong_reward
        WHERE
            1 = 1
            AND reward_time IS NOT NULL
    )
SELECT
    data_range,
    COALESCE(abnormal_per_day_per_user_status, '00_all') AS abnormal_per_day_per_user_status,
    user_get_reward_cnt
FROM
    (
        SELECT
            CONCAT(MIN(ds), '->', MAX(ds))                       AS data_range,
            COALESCE(abnormal_per_day_per_user_status, '00_all') AS abnormal_per_day_per_user_status,
            COUNT(DISTINCT the1_crd_no)                          AS user_get_reward_cnt
        FROM
            (
                SELECT
                    CASE
                        WHEN max_reward_time_per_user > 3 THEN '01_Yes'
                        ELSE '02_No'
                    END AS abnormal_per_user_status,
                    CASE
                        WHEN max_reward_time_one_day_per_user > 3 THEN '01_Yes'
                        ELSE '02_No'
                    END AS abnormal_per_day_per_user_status,
                    *
                FROM
                    (
                        SELECT
                            MAX(reward_time_one_day_per_user) OVER (
                                PARTITION BY
                                    the1_crd_no
                            ) AS max_reward_time_one_day_per_user,
                            MAX(reward_time_per_user) OVER (
                                PARTITION BY
                                    the1_crd_no
                            ) AS max_reward_time_per_user,
                            *
                        FROM
                            (
                                SELECT
                                    ROW_NUMBER() OVER (
                                        PARTITION BY
                                            ds,
                                            the1_crd_no
                                        ORDER BY
                                            ds,
                                            the1_crd_no
                                    ) AS reward_time_one_day_per_user,
                                    ROW_NUMBER() OVER (
                                        PARTITION BY
                                            the1_crd_no
                                        ORDER BY
                                            ds
                                    ) AS reward_time_per_user,
                                    *
                                FROM
                                    t_dwd
                            )
                    )
            )
        GROUP BY
            CUBE (abnormal_per_day_per_user_status)
    )
ORDER BY
    COALESCE(abnormal_per_day_per_user_status, '00_all')
;