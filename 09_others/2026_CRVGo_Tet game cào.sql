-- Active: 1763694043295@@ora-dwhdb-pri.centralretail.com.vn@1521@DWHDB@OMNI_DIGIMGR
-- WITH
--     t_dwd AS (
--         SELECT
--             FORMAT_DATE ('%Y-%m-%d', DATE (reward_time)) AS ds,
--             *
--         FROM
--             loutruongdataplatform1.loutruong_dwd.loutruong_reward
--         WHERE
--             1 = 1
--             AND reward_time IS NOT NULL
--     )
-- SELECT
--     CASE
--         WHEN max_reward_time_per_user > 3 THEN 'Yes'
--         ELSE 'No'
--     END AS abnormal_per_user,
--     CASE
--         WHEN max_reward_time_one_day_per_user > 3 THEN 'Yes'
--         ELSE 'No'
--     END AS abnormal_per_day_per_user,
--     *
-- FROM
--     (
--         SELECT
--             MAX(reward_time_one_day_per_user) OVER (
--                 PARTITION BY
--                     the1_crd_no
--             ) AS max_reward_time_one_day_per_user,
--             MAX(reward_time_per_user) OVER (
--                 PARTITION BY
--                     the1_crd_no
--             ) AS max_reward_time_per_user,
--             *
--         FROM
--             (
--                 SELECT
--                     ROW_NUMBER() OVER (
--                         PARTITION BY
--                             ds,
--                             the1_crd_no
--                         ORDER BY
--                             ds,
--                             the1_crd_no
--                     ) AS reward_time_one_day_per_user,
--                     ROW_NUMBER() OVER (
--                         PARTITION BY
--                             the1_crd_no
--                         ORDER BY
--                             ds
--                     ) AS reward_time_per_user,
--                     *
--                 FROM
--                     t_dwd
--             )
--     )
-- ;
SELECT
    TO_CHAR(SALE_DATE, 'yyyy-mm-dd') AS SALE_DATE,
    SUPPLIER_CODE,
    SUPPLIER_NAME,
    DIMENSION_GROUP,
    DIMENSION,
    NET_SALES,
    ORD_CNT,
    BYR_CNT,
    MARGIN
FROM
    crv_data.loutruong_supplier_perf_di
WHERE
    1 = 1
    AND LOWER(supplier_code) IN ('00_all_omni')
    AND LOWER(dimension) IN ('app')
    AND SALE_DATE >= '30-JAN-2026'
ORDER BY
    SALE_DATE ASC
;

-- SELECT
--     AVG(NET_SALES) / 1000000000 AS AVG_NET_SALES,
--     AVG(ORD_CNT)                AS AVG_ORD_CNT
-- FROM
--     crv_data.loutruong_supplier_perf_di
-- WHERE
--     1 = 1
--     AND LOWER(supplier_code) IN ('00_all_omni')
--     AND LOWER(dimension) IN ('app')
--     AND SALE_DATE BETWEEN '01-OCT-2025' AND '31-DEC-2025'
-- ;