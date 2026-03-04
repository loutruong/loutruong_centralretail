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