-- Active: 1763694043295@@ora-dwhdb-pri.centralretail.com.vn@1521
-- dwh.oms_order_header
-- dwh.oms_stock_item
-- dwh.oms_order_customer
-- dwh.oms_order_payment
-- dwh.oms_order_details_disount
-- dwh.oms_order_tracking
-- dwh.oms_sale_order_item_ytd
-- dwh.oms_pascal_b2b_order
-- dwh.oms_first_buy_date_store
-- prodbigcmobile.st_order_transaction
-- prodbigcmobile.st_pmh

SELECT
	COUNT(DISTINCT ORDERID) AS ORDER_CNT,
	COUNT(*) AS RN
FROM
	(
	SELECT
		*
	FROM
		DWH.OMS_ORDER_HEADER
	WHERE
		1 = 1
		AND CHANNEL = '0021'
		AND ORDER_DATE BETWEEN TIMESTAMP '2024-02-25 00:00:00.000000' AND TIMESTAMP '2024-02-25 23:59:59.999999') oh
	--<< 1
LEFT JOIN (
	SELECT
		*
	FROM
		DWH.OMS_ORDER_DETAILS
) od
	--<< 2
ON
	oh.ORDERID = od.ORDERID
LEFT JOIN (
	SELECT
		*
	FROM
		DWH.OMS_ORDER_DETAILS_DISCOUNT
) dd
	--<< 3
ON
	oh.ORDERID = dd.ORDERID
LEFT JOIN (
	SELECT
		*
	FROM
		dwh.OMS_ORDER_PAYMENT
) op
	--< 4
ON
	oh.ORDERID = op.ORDERID
LEFT JOIN (
	SELECT
		*
	FROM
		dwh.OMS_ORDER_TRACKING
) ot
ON
	oh.ORDERID = ot.ORDERID
	--< 5
LEFT JOIN (
	SELECT
		*
	FROM
		DWH.OMS_ORDER_CUSTOMER
) oc
	--<< 6
	--<< To get byr information
ON
	oh.ORDERID = oc.ORDERID;


SELECT
		
		*
	FROM
		DWH.OMS_ORDER_HEADER WHERE 1=1 AND ORDERNO IN ('5021926',
'5022126',
'5027213',
'5021920',
'5027612',
'5022150',
'5022003',
'5021923',
'5021943',
'5022125',
'5021921',
'5021922',
'5021919'
);
