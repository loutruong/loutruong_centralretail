-- mc_app
SELECT
	DATE (t.created_at) order_date,
	id_pmh,
	pmh.name            scheme_name,
	pmh.discount        scheme_discount,
	pmh.total           scheme_min_order_value,
	pmh.code_search     public_code,
	CASE
		WHEN t.status = 4 THEN 'Yes'
		ELSE 'No'
	END is_complete,
	t.vll_code vouchercode
	-- , COUNT(t.id) num_order
,
	SUM(t.total_price_normal) app_gmv
	-- , COUNT(DISTINCT t.customer_id) num_customer
FROM
	prodbigcmobile.st_order_transaction t
	LEFT JOIN prodbigcmobile.st_pmh pmh ON t.id_pmh = pmh.id
WHERE
	1 = 1
	-- AND t.created_at >= '2024-01-01'
	AND t.created_at >= '2024-12-01'
	AND t.id_pmh != 0
GROUP BY
	1,
	2,
	3,
	4,
	5,
	6,
	7,
	8
;

-- oms
SELECT
	oi.ORDER_DATE,
	os.orderno,
	os.vouchercode,
	DP.PRODUCT_CODE,
	DP.DIVISION,
	DP.DEPARTMENT,
	CONVERT(DP.PRODUCT_NAME, 'UTF8') PRODUCT_NAME,
	CASE
		WHEN ORDER_STATUS_ID IN ('0999') THEN 'Yes'
		ELSE 'No'
	END is_complete,
	SUM(gross_sales) app_gmv,
	CASE
		WHEN ob.FIRST_BUY_DATE = oi.ORDER_DATE
		AND ob.storeid = oi.STOREID THEN 'NC'
		ELSE 'EC'
	END customer_type,
	op.SEGMENT,
	oi.REGION,
	oi.SITE_NAME
	--, oi.STOREID
FROM
	OMS_SALE_ORDER_ITEM_YTD oi
	LEFT JOIN dim_channel dc ON oi.ONLINE_CHANNEL = dc.ONLINE_CHANNEL
	LEFT JOIN DIM_PRODUCT dp ON oi.PRODUCT_CODE = dp.PRODUCT_CODE
	LEFT JOIN OMS_ORDER_STATUS os ON oi.orderid = os.orderid
	LEFT JOIN OMS_PASCAL_B2B_ORDER op ON oi.orderid = op.orderid
	LEFT JOIN OMS_FIRST_BUY_DATE_STORE ob ON ob.FIRST_BUY_DATE = oi.ORDER_DATE
	AND ob.storeid = oi.STOREID
	AND ob.phone_number = oi.PHONE_NUMBER
WHERE
	1 = 1
	AND dc.SHORT_NAME IN ('APP')
	AND oi.order_date >= '01-JAN-24'
	AND oi.order_date < TRUNC(sysdate)
	AND dp.department IS NOT NULL
	AND os.vouchercode IS NOT NULL
GROUP BY
	oi.ORDER_DATE,
	os.orderno,
	os.vouchercode,
	DP.PRODUCT_CODE,
	DP.DIVISION,
	DP.DEPARTMENT,
	CONVERT(DP.PRODUCT_NAME, 'UTF8'),
	CASE
		WHEN ORDER_STATUS_ID IN ('0999') THEN 'Yes'
		ELSE 'No'
	END,
	CASE
		WHEN ob.FIRST_BUY_DATE = oi.ORDER_DATE
		AND ob.storeid = oi.STOREID THEN 'NC'
		ELSE 'EC'
	END,
	op.segment,
	oi.REGION,
	oi.SITE_NAME
	--, OI.STOREID
ORDER BY
	oi.order_date
;

WITH
	oms AS (
		SELECT
			TO_CHAR(y.order_Date, 'YYYY-MM-DD') AS ORDER_OMS_CREATED_DATE,
			y.storeid                           AS siteid,
			y.orderid,
			os.orderno,
			y.TICKETNO,
			si.product_code
			-- , max(barcode) AS barcode
,
			y.ONLINE_CHANNEL,
			os.phone_number,
			b2b.segment AS order_segment,
			os.VOUCHERCODE,
			SUM(si.GROSS_SALES) gmv
		FROM
			OMS_SALE_ORDER_YTD y
			LEFT JOIN oms_order_status os ON y.orderid = os.orderid
			LEFT JOIN OMS_PASCAL_B2B_ORDER b2b ON y.orderid = b2b.orderid
			LEFT JOIN OMS_SALE_ORDER_ITEM_YTD si ON y.orderid = si.orderid
			-- LEFT JOIN dwh.OMS_ORDER_DETAILS od ON od.orderid = y.orderid and si.product_code = od.goldcode || '-' || od.sv
		WHERE
			1 = 1 -- y.storeid = 109
			AND y.order_date >= '01-Jul-2025'
			AND y.order_date < '17-sep-2025'
		GROUP BY
			TO_CHAR(y.order_Date, 'YYYY-MM-DD'),
			y.orderid,
			y.storeid,
			os.orderno,
			y.TICKETNO,
			si.product_code,
			y.ONLINE_CHANNEL,
			b2b.segment,
			os.VOUCHERCODE,
			os.phone_number
	),
	pos AS (
		SELECT
			TO_CHAR(pos.sale_date, 'YYYY-MM-DD') AS ORDER_POS_CREATED_DATE,
			pos.site_code                        AS siteid,
			pos.orderno,
			pos.TICKETNO,
			si.product_code,
			MAX(BARCODE_GOLD)                    AS barcode,
			pos.ONLINE_CHANNEL,
			(
				CASE
					WHEN b2b.order_code IS NOT NULL THEN 'B2B'
					ELSE 'B2C'
				END
			) AS segment,
			v.CODEREF,
			SUM(si.GROSS_SALES) gross_sales,
			SUM(si.NET_SALES) net_sales
		FROM
			sale_order_ytd pos -- ON os.ORDERNO = pos.ORDERNO 
			LEFT JOIN CMS_ORDER_VOUCHER v ON pos.ORDER_CODE = v.ORDER_CODE
			LEFT JOIN SALE_ORDER_ITEM_YTD si ON pos.order_code = si.order_code
			LEFT JOIN (
				SELECT DISTINCT
					site_id || SALE_DATE || SUBSTR('000000' || TICKET_ID, -6, 6) || SUBSTR('000' || pos_id, -3, 3) AS order_code,
					product_code
				FROM
					crv_data.v_com_b2b
				WHERE
					b2b_type = 'step1'
					AND 1 = 1 -- site_id = 109 
					AND sale_date >= '01-Jul-2025'
					AND sale_date < '17-sep-2025'
			) b2b ON b2b.order_code = pos.order_code
			AND si.product_code = b2b.product_code
		WHERE
			1 = 1
			-- AND pos.site_code = 109
			AND pos.sale_date >= '01-Jul-2025'
			AND pos.sale_date < '17-sep-2025'
		GROUP BY
			TO_CHAR(pos.sale_date, 'YYYY-MM-DD'),
			pos.orderno,
			pos.site_Code,
			pos.TICKETNO,
			b2b.order_code,
			si.product_code,
			pos.ONLINE_CHANNEL,
			v.CODEREF
	)
SELECT
	oms.ORDER_OMS_CREATED_DATE,
	pos.ORDER_POS_CREATED_DATE,
	TO_CHAR(oms.orderid)                   AS order_id,
	COALESCE(oms.orderno, pos.orderno)     AS orderno,
	COALESCE(oms.TICKETNO, pos.TICKETNO)   TICKETNO,
	oms.phone_number,
	dp.product_code                        AS GOLD_SV,
	dpb.BARCODE,
	CONVERT(dp.product_name, 'utf8')       AS ITEM_NAME,
	dp.division_group                      AS DIVISION,
	dc.oms_channel                         AS CHANNEL_ID,
	dc.online_channel                      AS CHANNEL_NAME,
	pos.segment                            AS CUSTOMER_SEGMENT,
	oms.ORDER_SEGMENT,
	nvl2 (fbd.orderid, 'NC', 'EC')         AS CUSTOMER_TYPE,
	bs.region                              AS REGION_NAME,
	bs.siteid                              AS SITE_ID,
	bs.sitename                            AS SITE_NAME,
	COALESCE(oms.vouchercode, pos.coderef) AS VOUCHER_VLL_CODE
	--, VOUCHER_ID_PMH
	--, VOUCHER_ID_PMH_DISCOUNT
	--, VOUCHER_ID_PMH_MBS
	--, VOUCHER_ID_PMH_NAME
,
	oms.GMV,
	pos.GROSS_SALES,
	pos.NET_SALEs
FROM
	oms
	FULL JOIN pos ON oms.ORDERNO = pos.ORDERNO
	AND oms.product_code = pos.product_code
	LEFT JOIN dim_channel dc ON COALESCE(oms.ONLINE_CHANNEL, pos.ONLINE_CHANNEL) = dc.ONLINE_CHANNEL
	LEFT JOIN V_HYPER_DIM_PRODUCT dp ON COALESCE(oms.product_code, pos.product_code) = dp.product_code
	LEFT JOIN (
		SELECT
			product_code,
			MIN(barcode_gold) AS barcode
		FROM
			DIM_PRODUCT_BARCODE
		GROUP BY
			product_code
	) dpb ON dpb.product_code = dp.product_code
	LEFT JOIN nguyenthelam.oms_first_buy_date fbd ON oms.orderid = fbd.orderid
	LEFT JOIN BRAND_SITE bs ON COALESCE(oms.siteid, TO_CHAR(pos.siteid)) = bs.siteid
;

WITH s AS 
  (
      SELECT column_value AS view_code
      FROM TABLE(SYS.ODCIVARCHAR2LIST(
          'view1',
          'view2',
          'view3',
          'view4',
          'view5'
      ))
  ), df AS 
  (
    SELECT fldcre AS sale_date
      , bs.siteid AS store_id
      , bs.sitename AS store_name
      , nvl(dc.SHORT_NAME, 'OFFLINE') as channel
      , CASE WHEN clie.JCRCOD1 = '0039' THEN 1 else 0 END is_scan_n_go
      , clie.MAGCODE || clie.FLDCRE || clie.TNUMTIK || clie.TCODTPV AS order_code
      , JVTETOT - nvl(JVTETVA,0) AS net_sales
      , CASE WHEN bs.siteid = 134 
              AND dc.SHORT_NAME = 'APP' THEN 1 ELSE 0 END AS view1
      , CASE WHEN clie.JCRCOD1 = '0039' 
              AND JCRCOD3 NOT IN ('SG9', 'SG10', 'SG11', 'SG12', 'SG13', 'SG14', 'SG15'
                                  , 'SG17', 'SG21', 'SG23', 'SG31', 'SG32', 'SG33', 'SG39'
                                  , 'SG42', 'SG43', 'SG44', 'SG45', 'SG50', 'SG55', 'SG57'
                                  , 'SG58', 'SG60') THEN 1 ELSE 0 END AS view2
      , CASE WHEN dc.SHORT_NAME = 'WEB' THEN 1 ELSE 0 END AS view3
      , CASE WHEN dc.SHORT_NAME = 'WEB' 
            AND bs.siteid IN (103,133,102,108,111,122) THEN 1 ELSE 0 END AS view4
      , CASE WHEN bs.siteid = 134 THEN 1 ELSE 0 END AS view5
    FROM cms.ljclie clie
    JOIN NGUYENTHELAM.v_pbi_BRAND_SITE bs ON bs.siteid = clie.MAGCODE 
    LEFT JOIN nguyenthelam.DIM_CHANNEL dc ON dc.OMS_CHANNEL = clie.JCRCOD1
    WHERE 1 =1 
      AND FLDCRE = :sale_date 
      AND janntik = 0 
  )
SELECT 
    sale_date
    , CASE s.view_code
        WHEN 'view1' THEN 'Tops Thao Dien - App'
        WHEN 'view2' THEN 'Scan & Go!'
        WHEN 'view3' THEN 'Website'
        WHEN 'view4' THEN 'Website 6 stores launch (Omni + Offline)'
        WHEN 'view5' THEN 'Tops Thao Dien total (Omni + Offline)'
      END AS dimensions
    , sum(CASE s.view_code
          WHEN 'view1' THEN view1
          WHEN 'view2' THEN view2
          WHEN 'view3' THEN view3
          WHEN 'view4' THEN view4
          WHEN 'view5' THEN view5
        END) AS orders
    , sum(CASE s.view_code
          WHEN 'view1' THEN view1
          WHEN 'view2' THEN view2
          WHEN 'view3' THEN view3
          WHEN 'view4' THEN view4
          WHEN 'view5' THEN view5
        END * net_sales) AS net_sales
FROM df, s
GROUP BY sale_date, view_code;
