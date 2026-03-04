-- Active: 1763694043295@@ora-dwhdb-pri.centralretail.com.vn@1521@DWHDB@OMNI_DIGIMGR
--@@ Input: CRV_DATA.HYPER_MKT_VOUCHER_DATA_OMS -- trd_core order table
--@@ Input: CRV_DATA.HYPER_MKT_VOUCHER_DATA_MC_APP -- dim voucher table
SELECT
   t1.*
FROM
   (
      SELECT
         ORDER_DATE,
         ORDERNO,
         VOUCHERCODE,
         PRODUCT_CODE,
         DIVISION,
         DEPARTMENT,
         PRODUCT_NAME,
         IS_COMPLETE,
         APP_GMV,
         CUSTOMER_TYPE,
         SEGMENT,
         REGION,
         SITE_NAME
      FROM
         CRV_DATA.HYPER_MKT_VOUCHER_DATA_OMS
   ) t1
   LEFT JOIN (
      SELECT
         ORDER_DATE,
         ID_PMH,
         SCHEME_NAME,
         SCHEME_DISCOUNT,
         SCHEME_MIN_ORDER_VALUE,
         PUBLIC_CODE,
         IS_COMPLETE,
         VOUCHERCODE,
         APP_GMV
      FROM
         CRV_DATA.HYPER_MKT_VOUCHER_DATA_MC_APP
   ) t2 ON t1.VOUCHERCODE=t2.VOUCHERCODE
   AND t1.ORDER_DATE=t2.ORDER_DATE
;