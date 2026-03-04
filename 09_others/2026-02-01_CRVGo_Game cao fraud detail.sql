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
    CASE
        WHEN max_reward_time_per_user > 3 THEN 'Yes'
        ELSE 'No'
    END AS abnormal_per_user,
    CASE
        WHEN max_reward_time_one_day_per_user > 3 THEN 'Yes'
        ELSE 'No'
    END AS abnormal_per_day_per_user,
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
;