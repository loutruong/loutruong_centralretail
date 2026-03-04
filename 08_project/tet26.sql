SELECT
	period                        AS period,
	COALESCE(aov_range, '00_all') AS aov_range,
	COUNT(DISTINCT byr_id)        AS byr_cnt,
	COUNT(DISTINCT order_id)      AS ord_cnt,
	SUM(order_gmv_good_before_vc) AS order_gmv_good_before_vc
FROM
	(
		SELECT
			ds,
			period,
			byr_id,
			order_id,
			order_gmv_good,
			order_shipping_fee,
			order_discount_value,
			gmv_mc,
			order_gmv_good_before_vc,
			CASE
				WHEN order_gmv_good_before_vc >= 0
				AND order_gmv_good_before_vc < 50000 THEN 'R01: >=0k and <50k'
				WHEN order_gmv_good_before_vc >= 50000
				AND order_gmv_good_before_vc < 100000 THEN 'R02: >=50k and <100k'
				WHEN order_gmv_good_before_vc >= 100000
				AND order_gmv_good_before_vc < 150000 THEN 'R03: >=100k and <150k'
				WHEN order_gmv_good_before_vc >= 150000
				AND order_gmv_good_before_vc < 200000 THEN 'R04: >=150k and <200k'
				WHEN order_gmv_good_before_vc >= 200000
				AND order_gmv_good_before_vc < 250000 THEN 'R05: >=200k and <250k'
				WHEN order_gmv_good_before_vc >= 250000
				AND order_gmv_good_before_vc < 300000 THEN 'R06: >=250k and <300k'
				WHEN order_gmv_good_before_vc >= 300000
				AND order_gmv_good_before_vc < 350000 THEN 'R07: >=300k and <350k'
				WHEN order_gmv_good_before_vc >= 350000
				AND order_gmv_good_before_vc < 400000 THEN 'R08: >=350k and <400k'
				WHEN order_gmv_good_before_vc >= 400000
				AND order_gmv_good_before_vc < 450000 THEN 'R09: >=400k and <450k'
				WHEN order_gmv_good_before_vc >= 450000
				AND order_gmv_good_before_vc < 500000 THEN 'R10: >=450k and <500k'
				WHEN order_gmv_good_before_vc >= 500000
				AND order_gmv_good_before_vc < 550000 THEN 'R11: >=500k and <550k'
				WHEN order_gmv_good_before_vc >= 550000
				AND order_gmv_good_before_vc < 600000 THEN 'R12: >=550k and <600k'
				WHEN order_gmv_good_before_vc >= 600000
				AND order_gmv_good_before_vc < 650000 THEN 'R13: >=600k and <650k'
				WHEN order_gmv_good_before_vc >= 650000
				AND order_gmv_good_before_vc < 700000 THEN 'R14: >=650k and <700k'
				WHEN order_gmv_good_before_vc >= 700000 THEN 'R15: >=700k'
				ELSE 'R00: Unknow'
			END AS aov_range
		FROM
			(
				SELECT
					TO_CHAR(oh.ORDER_DATE, 'yyyy-mm-dd') AS ds,
					CASE
						WHEN (
							oh.ORDER_DATE BETWEEN TIMESTAMP '2023-12-27 00:00:00.000000' AND TIMESTAMP  '2024-02-25 23:59:59.999999'
						) THEN 'tet24'
						WHEN (
							oh.ORDER_DATE BETWEEN TIMESTAMP '2024-12-15 00:00:00.000000' AND TIMESTAMP  '2025-02-13 23:59:59.999999'
						) THEN 'tet25'
						ELSE NULL
					END AS period,
					oc.PHONE AS byr_id,
					oh.ORDERNO AS order_id,
					SUM(
						CASE
							WHEN oh.VER = 'V2' THEN CASE
								WHEN od.status IN ('0001', '0015') THEN 0
								WHEN od.TYPE = 2 THEN COALESCE(od.PRICEBFDISCOUNT, 0) * COALESCE(od.QTY, 0) + COALESCE(dd.TOTALDISCOUNT, 0)
								ELSE od.AMTTOTAL
							END
							ELSE od.AMTTOTAL
						END
					) AS order_gmv_good,
					MAX(COALESCE(oh.SHIPPING_FEE, 0)) AS order_shipping_fee,
					MAX(COALESCE(oh.INTERNAL_AMTPROMO, 0)) AS order_discount_value,
					SUM(
						CASE
							WHEN oh.VER = 'V2' THEN CASE
								WHEN od.status IN ('0001', '0015') THEN 0
								WHEN od.TYPE = 2 THEN COALESCE(od.PRICEBFDISCOUNT, 0) * COALESCE(od.QTY, 0) + COALESCE(dd.TOTALDISCOUNT, 0)
								ELSE od.AMTTOTAL
							END
							ELSE od.AMTTOTAL
						END
					) + MAX(COALESCE(oh.SHIPPING_FEE, 0)) AS gmv_mc,
					SUM(
						CASE
							WHEN oh.VER = 'V2' THEN CASE
								WHEN od.status IN ('0001', '0015') THEN 0
								WHEN od.TYPE = 2 THEN COALESCE(od.PRICEBFDISCOUNT, 0) * COALESCE(od.QTY, 0) + COALESCE(dd.TOTALDISCOUNT, 0)
								ELSE od.AMTTOTAL
							END
							ELSE od.AMTTOTAL
						END
					) + MAX(COALESCE(oh.INTERNAL_AMTPROMO, 0)) AS order_gmv_good_before_vc
				FROM
					(
						SELECT
							*
						FROM
							DWH.OMS_ORDER_HEADER
						WHERE
							1 = 1
							AND (
								ORDER_DATE BETWEEN TIMESTAMP '2023-12-27 00:00:00.000000' AND TIMESTAMP  '2024-02-25 23:59:59.999999'
								OR ORDER_DATE BETWEEN TIMESTAMP '2024-12-15 00:00:00.000000' AND TIMESTAMP  '2025-02-13 23:59:59.999999'
							)
							AND CHANNEL IN ('0021')
					) oh
					--<< 1
					LEFT JOIN (
						SELECT
							*
						FROM
							DWH.OMS_ORDER_DETAILS
					) od
					--<< 2
					ON oh.ORDERID = od.ORDERID
					LEFT JOIN (
						SELECT
							*
						FROM
							DWH.OMS_ORDER_DETAILS_DISCOUNT
					) dd
					--<< 3
					ON od.ORDERID = dd.ORDERID
					AND od.LINE = dd.LINE
					LEFT JOIN (
						SELECT
							*
						FROM
							DWH.OMS_ORDER_CUSTOMER
					) oc ON oh.ORDERID = oc.ORDERID
				GROUP BY
					TO_CHAR(oh.ORDER_DATE, 'yyyy-mm-dd'),
					CASE
						WHEN (
							oh.ORDER_DATE BETWEEN TIMESTAMP '2023-12-27 00:00:00.000000' AND TIMESTAMP  '2024-02-25 23:59:59.999999'
						) THEN 'tet24'
						WHEN (
							oh.ORDER_DATE BETWEEN TIMESTAMP '2024-12-15 00:00:00.000000' AND TIMESTAMP  '2025-02-13 23:59:59.999999'
						) THEN 'tet25'
						ELSE NULL
					END,
					oh.ORDERNO,
					oc.PHONE
			)
	)
GROUP BY
	period,
	CUBE (aov_range)
ORDER BY
	period,
	COALESCE(aov_range, '00_all')
;