-- =====================================================================
-- VOUCHER PIPELINE (upstream)
-- =====================================================================

-- Flow:
--   1. DLK — Drop the CSV into gs://loutruong_dlk/crvgo_voucher/
--   2. ODS — External table: Reads CSVs as-is (all text); new files appear automatically. Raw, untouched.
--   3. DWD — Internal table (Native table) the table you query: Typed + Partitioned by ds, built from ODS. Retention is automatic (see Mode A).
--
-- How to run (data lands D-1, so windows count back from yesterday):
--   • First time / After a column change                 -> Run [ODS] + [MODE A]   (Builds the whole table)
--   • Second time / Every day after uploading the file   -> Run [ODS] + [MODE B]   (Overwrites the last 7 days)
--   • QA time on both First or the Second time to sanity-check the per-month counts.

-- Remember:
--   • Mode A CREATES the table; Mode B needs it to exist — so start fresh with Mode A.
--   • Run ONE mode at a time (highlight the block and Run, or comment the other out).
--   • Retention = partition_expiration_days in Mode A (the LIFECYCLE equivalent): partitions auto-drop once they're older than N days from their own date. No manual trimming needed.
-- =====================================================================

-- =====================================================================
-- [ODS]  Always. Raw landing — external table over the lake CSVs.
-- All STRING, faithful to source. New files appear automatically.
-- =====================================================================

-- DROP EXTERNAL TABLE IF EXISTS `loutruongdataplatform1.loutruong_dwd.ods_voucher_df`;

CREATE OR REPLACE EXTERNAL TABLE `loutruongdataplatform1.loutruong_dwd.ods_voucher_df`(
  order_date STRING,
  order_no STRING,
  voucher_id STRING,
  voucher_vll_code STRING,
  voucher_public_code STRING,
  voucher_discount_value STRING,
  voucher_mbs STRING,
  voucher_name STRING,
  voucher_quantity_issue_daily STRING,
  gold_sv STRING,
  product_name STRING,
  division STRING,
  department STRING,
  is_complete STRING,
  customer_type STRING,
  customer_segment STRING,
  region STRING,
  site_name STRING,
  app_gmv STRING,
  source_month STRING)
  OPTIONS (
    format = 'CSV',
    uris = ['gs://loutruong_dlk/crvgo_voucher/*.csv'],
    skip_leading_rows = 1);

-- =====================================================================
-- [MODE A — BACKFILL]  Full rebuild from the lake.
-- Run once to initialise, or whenever you change columns / cast logic.
-- =====================================================================

-- DROP TABLE IF EXISTS `loutruongdataplatform1.loutruong_dwd.dwd_loutruong_voucher_di`;

-- CREATE OR REPLACE TABLE `loutruongdataplatform1.loutruong_dwd.dwd_loutruong_voucher_di`
--   PARTITION BY ds
--   OPTIONS (partition_expiration_days = 10000)
-- AS
-- SELECT
--   SAFE_CAST(SUBSTR(order_date, 1, 10) AS DATE) AS order_date,
--   order_no,
--   voucher_id,
--   voucher_vll_code,
--   voucher_public_code,
--   SAFE_CAST(voucher_discount_value AS NUMERIC) AS voucher_discount_value,
--   SAFE_CAST(voucher_mbs AS NUMERIC) AS voucher_mbs,
--   voucher_name,
--   SAFE_CAST(voucher_quantity_issue_daily AS INT64)
--     AS voucher_quantity_issue_daily,
--   gold_sv,
--   product_name,
--   division,
--   department,
--   is_complete,
--   customer_type,
--   customer_segment,
--   region,
--   site_name,
--   SAFE_CAST(app_gmv AS NUMERIC) AS app_gmv,
--   source_month,
--   SAFE_CAST(SUBSTR(order_date, 1, 10) AS DATE) AS ds
-- FROM `loutruongdataplatform1.loutruong_dwd.ods_voucher_df`;

-- =====================================================================
-- [MODE B — DAILY]  Dynamic partition overwrite via MERGE (atomic).
-- =====================================================================
MERGE INTO `loutruongdataplatform1.loutruong_dwd.dwd_loutruong_voucher_di` AS t1
USING (
  SELECT
    SAFE_CAST(SUBSTR(order_date, 1, 10) AS DATE) AS order_date,
    order_no,
    voucher_id,
    voucher_vll_code,
    voucher_public_code,
    SAFE_CAST(voucher_discount_value AS NUMERIC) AS voucher_discount_value,
    SAFE_CAST(voucher_mbs AS NUMERIC) AS voucher_mbs,
    voucher_name,
    SAFE_CAST(voucher_quantity_issue_daily AS INT64)
      AS voucher_quantity_issue_daily,
    gold_sv,
    product_name,
    division,
    department,
    is_complete,
    customer_type,
    customer_segment,
    region,
    site_name,
    SAFE_CAST(app_gmv AS NUMERIC) AS app_gmv,
    source_month,
    SAFE_CAST(SUBSTR(order_date, 1, 10) AS DATE) AS ds
  FROM `loutruongdataplatform1.loutruong_dwd.ods_voucher_df`
  WHERE
    SAFE_CAST(SUBSTR(order_date, 1, 10) AS DATE)
    >= DATE_SUB((CURRENT_DATE() - 1), INTERVAL 7 DAY)
) AS t2
ON
  FALSE
    WHEN
      NOT MATCHED BY SOURCE
      AND t1.ds >= DATE_SUB((CURRENT_DATE() - 1), INTERVAL 7 DAY)
      THEN DELETE
    WHEN NOT MATCHED THEN INSERT ROW;

-- =====================================================================
-- [QA]  Row counts and date span per source file.
-- =====================================================================
SELECT
  source_month,
  COUNT(*) AS r,
  MIN(order_date) AS first_day,
  MAX(order_date) AS last_day
FROM `loutruongdataplatform1.loutruong_dwd.dwd_loutruong_voucher_di`
GROUP BY source_month
ORDER BY source_month;


WITH
  base AS (
    SELECT *, LOWER(voucher_name) AS n
    FROM `loutruongdataplatform1.loutruong_dwd.dwd_loutruong_voucher_di`
    WHERE 1 = 1 AND lower(is_complete) = 'yes'
  ),
  tagged AS (
    SELECT
      * EXCEPT (n),
      CONCAT(voucher_discount_value / 1000, "k", " / ", voucher_mbs / 1000, "k")
        AS scheme,

      -- voucher_type — numbered label; channel tags (CRM) win over occasion (birthday)
      CASE
        WHEN n LIKE '%sorry%' THEN '06_Apology (Sorry)'
        WHEN n LIKE '%new customer%' AND n LIKE '%fresh%'
          THEN '05_Fresh Food'  -- NEW: Fresh New Customer → Fresh Food (above New Customer)
        WHEN n LIKE '%new customer%' THEN '01_New Customer'
        WHEN n LIKE '%next purchase%' THEN '09_Next Purchase'
        WHEN n LIKE '%livestream%' THEN '14_Livestream'
        WHEN
          REGEXP_CONTAINS(
            n,
            r'martech|\[zns\]|churn|ec voucher|moengage|\[moe\]|\[sms\]|zalo')
          THEN
            '04_CRM Push'  -- ABOVE birthday: "[ZNS] Member Birthday" = CRM push, not a store anniversary
        WHEN n LIKE '%birthday%' THEN '11_Store Birthday'
        WHEN REGEXP_CONTAINS(n, r'fresh|fruit festival') THEN '05_Fresh Food'
        WHEN n LIKE '%milk day%'
          THEN '03_Seasonal / Holiday / Thematic'  -- NEW: Mega extra Milk day → Seasonal (above Mega)
        WHEN n LIKE '%mega%' THEN '02_Mega Campaign'
        WHEN REGEXP_CONTAINS(n, r'minigame|lucky') THEN '07_Game / Minigame'
        WHEN n LIKE '%the1%' THEN '08_Loyalty (The1)'
        WHEN
          REGEXP_CONTAINS(
            n, r'vpbank|elmich|pns|pulse metrics| cp |partnership')
          THEN '10_Partnership'
        WHEN REGEXP_CONTAINS(n, r'opening|new store|new visual|renovation')
          THEN '12_Store Launch / Reno'
        WHEN
          REGEXP_CONTAINS(
            n,
            r'target store support|\[target store\]|target audience|special event|fair|support')
          THEN '13_Store Support & Targeting'
        WHEN
          REGEXP_CONTAINS(
            n,
            r'tet|year-end|tuần lễ vàng|8/3| mẹ|thiếu nhi|valentine|đại lễ|giỗ tổ|siêu sale|mở bát|international day|quốc tế|quốc khánh|khai xuân|festival|sale|deal|ưu đãi|tiệc sale|subcampaign|mừng|mooncake|trung thu|mid-autumn|tựu trường|12\.12')
          THEN '03_Seasonal / Holiday / Thematic'
        ELSE '99_Others'
        END AS voucher_type,

      -- clm_stage — WHO (lifecycle)
      CASE
        WHEN n LIKE '%new customer%' THEN 'New'
        WHEN REGEXP_CONTAINS(n, r'churn|winback') THEN 'Churn'
        WHEN REGEXP_CONTAINS(n, r'ec voucher|next purchase') THEN 'Existing'
        ELSE 'All'
        END AS clm_stage,

      -- division_scope
      CASE
        WHEN REGEXP_CONTAINS(n, r'fresh|fruit') THEN 'Fresh'
        WHEN REGEXP_CONTAINS(n, r'milk|dairy') THEN 'Dairy'
        ELSE 'Others'
        END AS division_scope,

      -- store_scope — [All] + untagged = Nationwide
      CASE
        WHEN REGEXP_CONTAINS(n, r'tier [1-4]|\[tier') THEN 'Targeted store tier'
        WHEN n LIKE '%target audience%' THEN 'Targeted audience'
        WHEN
          REGEXP_CONTAINS(
            n,
            r'\[target store|birthday store|livestream -|renovation|special event|fair|opening|new store')
          THEN 'Targeted store'
        ELSE 'Nationwide'
        END AS store_scope,

      -- banner / BU
      CASE
        WHEN REGEXP_CONTAINS(n, r'go! & top|go & top') THEN 'GO! + Tops'
        WHEN REGEXP_CONTAINS(n, r'tops|thao dien') THEN 'Tops'
        ELSE 'GO!'
        END AS bu
    FROM base
  )
SELECT
  ds,
  voucher_type,
  clm_stage,
  division_scope,
  store_scope,
  bu,
  voucher_name,
  voucher_discount_value AS dv,
  voucher_mbs AS mov,
  scheme,
  voucher_discount_value * COUNT(DISTINCT order_no) AS spending,
  COUNT(DISTINCT order_no) AS ord_cnt,
  SUM(app_gmv) AS net_sales,
  customer_segment
FROM tagged
GROUP BY
  ds,
  voucher_type,
  clm_stage,
  division_scope,
  store_scope,
  bu,
  voucher_name,
  voucher_discount_value,
  voucher_mbs,
  scheme,
  customer_segment
ORDER BY ds ASC, voucher_type ASC, net_sales DESC;

-- WITH
--   base AS (
--     SELECT *, LOWER(voucher_name) AS n
--     FROM `loutruongdataplatform1.loutruong_dwd.dwd_loutruong_voucher_di`
--   ),
--   tagged AS (
--     SELECT DISTINCT
--       CONCAT(voucher_discount_value / 1000, " / ", voucher_mbs / 1000)
--         AS scheme,
--       CASE
--         WHEN n LIKE '%sorry%' THEN '06_Apology (Sorry)'
--         WHEN n LIKE '%new customer%' THEN '01_New Customer'
--         WHEN n LIKE '%next purchase%' THEN '09_Next Purchase'
--         WHEN n LIKE '%livestream%' THEN '14_Livestream'
--         WHEN
--           REGEXP_CONTAINS(
--             n,
--             r'martech|\[zns\]|churn|ec voucher|moengage|\[moe\]|\[sms\]|zalo')
--           THEN '04_CRM Push'
--         WHEN n LIKE '%birthday%' THEN '11_Store Birthday'
--         WHEN REGEXP_CONTAINS(n, r'fresh|fruit festival') THEN '05_Fresh Food'
--         WHEN n LIKE '%mega%' THEN '02_Mega Campaign'
--         WHEN REGEXP_CONTAINS(n, r'minigame|lucky') THEN '07_Game / Minigame'
--         WHEN n LIKE '%the1%' THEN '08_Loyalty (The1)'
--         WHEN
--           REGEXP_CONTAINS(
--             n, r'vpbank|elmich|pns|pulse metrics| cp |partnership')
--           THEN '10_Partnership'
--         WHEN REGEXP_CONTAINS(n, r'opening|new store|new visual|renovation')
--           THEN '12_Store Launch / Reno'
--         WHEN
--           REGEXP_CONTAINS(
--             n,
--             r'target store support|\[target store\]|target audience|special event|fair|support')
--           THEN '13_Store Support & Targeting'
--         WHEN
--           REGEXP_CONTAINS(
--             n,
--             r'tet|year-end|tuần lễ vàng|8/3| mẹ|thiếu nhi|valentine|đại lễ|giỗ tổ|siêu sale|mở bát|international day|quốc tế|quốc khánh|khai xuân|festival|sale|deal|ưu đãi|tiệc sale|subcampaign|mừng|mooncake|trung thu|mid-autumn|tựu trường|12\.12')
--           THEN '03_Seasonal / Holiday / Thematic'
--         ELSE '99_Others'
--         END AS voucher_type
--     FROM base
--   ),
--   rolled AS (
--     SELECT
--       scheme,
--       COUNT(*) AS distinct_type_count,
--       ARRAY_AGG(voucher_type ORDER BY voucher_type) AS t
--     FROM tagged
--     GROUP BY scheme
--   )
-- SELECT
--   scheme,
--   distinct_type_count,
--   t[SAFE_OFFSET(0)] AS type1,
--   t[SAFE_OFFSET(1)] AS type2,
--   t[SAFE_OFFSET(2)] AS type3,
--   t[SAFE_OFFSET(3)] AS type4,
--   t[SAFE_OFFSET(4)] AS type5,
--   t[SAFE_OFFSET(5)] AS type6
-- FROM rolled
-- ORDER BY distinct_type_count DESC, scheme;