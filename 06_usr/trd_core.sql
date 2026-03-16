DROP TABLE IF EXISTS loutruongdataplatform1.loutruong_dwd.loutruong_crvgo_trd_core_di
;

-- CREATE OR REPLACE EXTERNAL TABLE loutruongdataplatform1.loutruong_dwd.loutruong_crvgo_trd_core_di(
--   `SALE_DATE` STRING,
--   `MONTH` STRING,
--   `ONLINE_CHANNEL` STRING,
--   `CUSTOMER_TYPE` STRING,
--   `SITE_NAME` STRING,
--   `REGION` STRING,
--   `NET_SALES` FLOAT64,
--   `MARGIN` FLOAT64,
--   `QTY` FLOAT64,
--   `PRODUCT_CODE` STRING)
--   OPTIONS (
--     format = 'CSV',
--     uris = ['gs://loutruong_dlk/crvgo_trd_core/*.csv'],
--     skip_leading_rows = 1,
--     allow_quoted_newlines = TRUE);
SELECT
    SALE_DATE,
    MONTH,
    ONLINE_CHANNEL,
    CUSTOMER_TYPE,
    SITE_NAME,
    REGION,
    NET_SALES,
    MARGIN,
    QTY,
    PRODUCT_CODE
FROM
    loutruongdataplatform1.loutruong_dwd.loutruong_crvgo_trd_core_di
;