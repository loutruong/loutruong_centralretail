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