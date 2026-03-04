-----------------------
WITH
	t_dwd AS (
		SELECT
			ORDER_DATE_POS_RECORDED AS ds,
			CASE
				WHEN period IN ('2024-12-15 -> 2025-03-15') THEN 'tet25'
				WHEN period IN ('2023-12-27 -> 2024-03-26') THEN 'tet24'
				ELSE 'Unknown'
			END AS period,
			CASE
				WHEN COALESCE(NET_SALES, 0) >= 0
				AND COALESCE(NET_SALES, 0) < 50000 THEN 'R01: >=0k and <50k'
				WHEN COALESCE(NET_SALES, 0) >= 50000
				AND COALESCE(NET_SALES, 0) < 100000 THEN 'R02: >=50k and <100k'
				WHEN COALESCE(NET_SALES, 0) >= 100000
				AND COALESCE(NET_SALES, 0) < 150000 THEN 'R03: >=100k and <150k'
				WHEN COALESCE(NET_SALES, 0) >= 150000
				AND COALESCE(NET_SALES, 0) < 200000 THEN 'R04: >=150k and <200k'
				WHEN COALESCE(NET_SALES, 0) >= 200000
				AND COALESCE(NET_SALES, 0) < 250000 THEN 'R05: >=200k and <250k'
				WHEN COALESCE(NET_SALES, 0) >= 250000
				AND COALESCE(NET_SALES, 0) < 300000 THEN 'R06: >=250k and <300k'
				WHEN COALESCE(NET_SALES, 0) >= 300000
				AND COALESCE(NET_SALES, 0) < 350000 THEN 'R07: >=300k and <350k'
				WHEN COALESCE(NET_SALES, 0) >= 350000
				AND COALESCE(NET_SALES, 0) < 400000 THEN 'R08: >=350k and <400k'
				WHEN COALESCE(NET_SALES, 0) >= 400000
				AND COALESCE(NET_SALES, 0) < 450000 THEN 'R09: >=400k and <450k'
				WHEN COALESCE(NET_SALES, 0) >= 450000
				AND COALESCE(NET_SALES, 0) < 500000 THEN 'R10: >=450k and <500k'
				WHEN COALESCE(NET_SALES, 0) >= 500000
				AND COALESCE(NET_SALES, 0) < 550000 THEN 'R11: >=500k and <550k'
				WHEN COALESCE(NET_SALES, 0) >= 550000
				AND COALESCE(NET_SALES, 0) < 600000 THEN 'R12: >=550k and <600k'
				WHEN COALESCE(NET_SALES, 0) >= 600000
				AND COALESCE(NET_SALES, 0) < 650000 THEN 'R13: >=600k and <650k'
				WHEN COALESCE(NET_SALES, 0) >= 650000
				AND COALESCE(NET_SALES, 0) < 700000 THEN 'R14: >=650k and <700k'
				WHEN COALESCE(NET_SALES, 0) >= 700000 THEN 'R15: >=700k'
				ELSE 'R16: Unknow'
			END AS aov_range,
			PHONE_NUMBER AS byr_id,
			CONCAT(ORDER_DATE_POS_RECORDED, SITEID, TICKETNO) AS ord_id,
			NET_SALES AS net_sale
		FROM
			loutruongdataplatform1.loutruong_dwd.tet
		WHERE
			1 = 1
			AND (
				ORDER_DATE_POS_RECORDED BETWEEN '2023-12-27' AND '2024-02-25'
				OR ORDER_DATE_POS_RECORDED BETWEEN '2024-12-15' AND '2025-02-13'
			)
			AND CHANNEL_ID IN (0021)
	)
SELECT
	COALESCE(period, '00_all')    AS period,
	COALESCE(aov_range, '00_all') AS aov_range,
	byr_cnt,
	ord_cnt,
	net_sale
FROM
	(
		SELECT
			period,
			aov_range,
			COUNT(DISTINCT byr_id)  AS byr_cnt,
			COUNT(DISTINCT ord_id)  AS ord_cnt,
			SUM(COALESCE(net_sale)) AS net_sale
		FROM
			t_dwd
		GROUP BY
			CUBE (period, aov_range)
	)
WHERE
	1 = 1
	AND period IS NOT NULL
ORDER BY
	COALESCE(period, '00_all'),
	COALESCE(aov_range, '00_all')
;

WITH
	t_dwd AS (
		SELECT
			CASE
				WHEN period IN ('2024-12-15 -> 2025-03-15') THEN 'tet25'
				WHEN period IN ('2023-12-27 -> 2024-03-26') THEN 'tet24'
				ELSE 'Unknown'
			END AS period,
			ORDER_DATE_POS_RECORDED AS ds,
			PHONE_NUMBER AS byr_id,
			CONCAT(ORDER_DATE_POS_RECORDED, SITEID, TICKETNO) AS ord_id,
			NET_SALES AS net_sale
		FROM
			loutruongdataplatform1.loutruong_dwd.tet
		WHERE
			1 = 1
			AND (
				ORDER_DATE_POS_RECORDED BETWEEN '2023-12-27' AND '2024-02-25'
				OR ORDER_DATE_POS_RECORDED BETWEEN '2024-12-15' AND '2025-02-13'
			)
			AND CHANNEL_ID = 0021
	)
SELECT
	period,
	ds,
	COUNT(DISTINCT byr_id)     AS byr_cnt,
	COUNT(DISTINCT ord_id)     AS ord_cnt,
	SUM(COALESCE(net_sale, 0)) AS gmv,
	COUNT(
		DISTINCT CASE
			WHEN COALESCE(net_sale, 0) >= 500000 THEN byr_id
			ELSE NULL
		END
	) AS byr_cnt_500k,
	COUNT(
		DISTINCT CASE
			WHEN COALESCE(net_sale, 0) >= 500000 THEN ord_id
			ELSE NULL
		END
	) AS ord_cnt_500k,
	SUM(
		CASE
			WHEN COALESCE(net_sale, 0) >= 500000 THEN COALESCE(net_sale, 0)
			ELSE 0
		END
	) AS gmv_500k,
	COUNT(
		DISTINCT CASE
			WHEN COALESCE(net_sale, 0) >= 600000 THEN byr_id
			ELSE NULL
		END
	) AS byr_cnt_600k,
	COUNT(
		DISTINCT CASE
			WHEN COALESCE(net_sale, 0) >= 600000 THEN ord_id
			ELSE NULL
		END
	) AS ord_cnt_600k,
	SUM(
		CASE
			WHEN COALESCE(net_sale, 0) >= 600000 THEN COALESCE(net_sale, 0)
			ELSE 0
		END
	) AS gmv_600k,
	COUNT(
		DISTINCT CASE
			WHEN COALESCE(net_sale, 0) >= 700000 THEN byr_id
			ELSE NULL
		END
	) AS byr_cnt_700k,
	COUNT(
		DISTINCT CASE
			WHEN COALESCE(net_sale, 0) >= 700000 THEN ord_id
			ELSE NULL
		END
	) AS ord_cnt_700k,
	SUM(
		CASE
			WHEN COALESCE(net_sale, 0) >= 700000 THEN COALESCE(net_sale, 0)
			ELSE 0
		END
	) AS gmv_700k
FROM
	t_dwd
GROUP BY
	period,
	ds
ORDER BY
	period,
	ds
;

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

WITH
	t_dwd_offline AS (
		SELECT
			CASE
				WHEN (SDATE BETWEEN '2023-12-27' AND '2024-02-25') THEN 'tet24'
				WHEN (SDATE BETWEEN '2024-12-15' AND '2025-02-13') THEN 'tet25'
				ELSE NULL
			END AS period,
			SDATE AS ds,
			CONCAT(SITEID, SALE_DATE, POS_NO, TICKET) AS order_id,
			card_no AS byr_id,
			net_sale,
			CASE
				WHEN net_sale >= 0
				AND net_sale < 50000 THEN 'R01: >=0k and <50k'
				WHEN net_sale >= 50000
				AND net_sale < 100000 THEN 'R02: >=50k and <100k'
				WHEN net_sale >= 100000
				AND net_sale < 150000 THEN 'R03: >=100k and <150k'
				WHEN net_sale >= 150000
				AND net_sale < 200000 THEN 'R04: >=150k and <200k'
				WHEN net_sale >= 200000
				AND net_sale < 250000 THEN 'R05: >=200k and <250k'
				WHEN net_sale >= 250000
				AND net_sale < 300000 THEN 'R06: >=250k and <300k'
				WHEN net_sale >= 300000
				AND net_sale < 350000 THEN 'R07: >=300k and <350k'
				WHEN net_sale >= 350000
				AND net_sale < 400000 THEN 'R08: >=350k and <400k'
				WHEN net_sale >= 400000
				AND net_sale < 450000 THEN 'R09: >=400k and <450k'
				WHEN net_sale >= 450000
				AND net_sale < 500000 THEN 'R10: >=450k and <500k'
				WHEN net_sale >= 500000
				AND net_sale < 550000 THEN 'R11: >=500k and <550k'
				WHEN net_sale >= 550000
				AND net_sale < 600000 THEN 'R12: >=550k and <600k'
				WHEN net_sale >= 600000
				AND net_sale < 650000 THEN 'R13: >=600k and <650k'
				WHEN net_sale >= 650000
				AND net_sale < 700000 THEN 'R14: >=650k and <700k'
				WHEN net_sale >= 700000 THEN 'R15: >=700k'
				ELSE 'R00: Unknow'
			END AS aov_range
		FROM
			(
				SELECT
					*
				FROM
					loutruongdataplatform1.loutruong_dwd.tet_off_24
				UNION ALL
				SELECT
					*
				FROM
					loutruongdataplatform1.loutruong_dwd.tet_off_25
			)
		WHERE
			1 = 1
			AND (
				SDATE BETWEEN '2023-12-27' AND '2024-02-25'
				OR SDATE BETWEEN '2024-12-15' AND '2025-02-13'
			)
			AND IS_ONLINE = 0
	)
SELECT
	period,
	COALESCE(aov_range, '00_all') AS aov_range,
	byr_cnt,
	ord_cnt,
	net_sales
FROM
	(
		SELECT
			period,
			aov_range                  AS aov_range,
			COUNT(DISTINCT byr_id)     AS byr_cnt,
			COUNT(DISTINCT order_id)   AS ord_cnt,
			SUM(COALESCE(net_sale, 0)) AS net_sales
		FROM
			t_dwd_offline
		GROUP BY
			CUBE (period, aov_range)
	)
WHERE
	1 = 1
	AND period IS NOT NULL
ORDER BY
	period,
	COALESCE(aov_range, '00_all')
;

WITH
	t_dwd_hyper AS (
		SELECT
			CASE
				WHEN (SDATE BETWEEN '2023-12-27' AND '2024-02-25') THEN 'tet24'
				WHEN (SDATE BETWEEN '2024-12-15' AND '2025-02-13') THEN 'tet25'
				ELSE NULL
			END AS period,
			SDATE AS ds,
			CONCAT(SITEID, SALE_DATE, POS_NO, TICKET) AS order_id,
			card_no AS byr_id,
			net_sale,
			CASE
				WHEN net_sale >= 0
				AND net_sale < 50000 THEN 'R01: >=0k and <50k'
				WHEN net_sale >= 50000
				AND net_sale < 100000 THEN 'R02: >=50k and <100k'
				WHEN net_sale >= 100000
				AND net_sale < 150000 THEN 'R03: >=100k and <150k'
				WHEN net_sale >= 150000
				AND net_sale < 200000 THEN 'R04: >=150k and <200k'
				WHEN net_sale >= 200000
				AND net_sale < 250000 THEN 'R05: >=200k and <250k'
				WHEN net_sale >= 250000
				AND net_sale < 300000 THEN 'R06: >=250k and <300k'
				WHEN net_sale >= 300000
				AND net_sale < 350000 THEN 'R07: >=300k and <350k'
				WHEN net_sale >= 350000
				AND net_sale < 400000 THEN 'R08: >=350k and <400k'
				WHEN net_sale >= 400000
				AND net_sale < 450000 THEN 'R09: >=400k and <450k'
				WHEN net_sale >= 450000
				AND net_sale < 500000 THEN 'R10: >=450k and <500k'
				WHEN net_sale >= 500000
				AND net_sale < 550000 THEN 'R11: >=500k and <550k'
				WHEN net_sale >= 550000
				AND net_sale < 600000 THEN 'R12: >=550k and <600k'
				WHEN net_sale >= 600000
				AND net_sale < 650000 THEN 'R13: >=600k and <650k'
				WHEN net_sale >= 650000
				AND net_sale < 700000 THEN 'R14: >=650k and <700k'
				WHEN net_sale >= 700000 THEN 'R15: >=700k'
				ELSE 'R00: Unknow'
			END AS aov_range
		FROM
			(
				SELECT
					*
				FROM
					loutruongdataplatform1.loutruong_dwd.tet_off_24
				UNION ALL
				SELECT
					*
				FROM
					loutruongdataplatform1.loutruong_dwd.tet_off_25
			)
		WHERE
			1 = 1
			AND (
				SDATE BETWEEN '2023-12-27' AND '2024-02-25'
				OR SDATE BETWEEN '2024-12-15' AND '2025-02-13'
			)
			AND IS_ONLINE = 0
	)
SELECT
	ds,
	COUNT(DISTINCT byr_id)     AS byr_cnt,
	COUNT(DISTINCT order_id)   AS ord_cnt,
	SUM(COALESCE(net_sale, 0)) AS net_sales,
	COUNT(
		DISTINCT CASE
			WHEN net_sale >= 500000 THEN byr_id
			ELSE NULL
		END
	) AS byr_cnt_500k,
	COUNT(
		DISTINCT CASE
			WHEN net_sale >= 500000 THEN order_id
			ELSE NULL
		END
	) AS ord_cnt_500k,
	SUM(
		CASE
			WHEN net_sale >= 500000 THEN net_sale
			ELSE 0
		END
	) AS net_sales_500k,
	COUNT(
		DISTINCT CASE
			WHEN net_sale >= 600000 THEN byr_id
			ELSE NULL
		END
	) AS byr_cnt_600k,
	COUNT(
		DISTINCT CASE
			WHEN net_sale >= 600000 THEN order_id
			ELSE NULL
		END
	) AS ord_cnt_600k,
	SUM(
		CASE
			WHEN net_sale >= 600000 THEN net_sale
			ELSE 0
		END
	) AS net_sales_600k,
	COUNT(
		DISTINCT CASE
			WHEN net_sale >= 700000 THEN byr_id
			ELSE NULL
		END
	) AS byr_cnt_700k,
	COUNT(
		DISTINCT CASE
			WHEN net_sale >= 700000 THEN order_id
			ELSE NULL
		END
	) AS ord_cnt_700k,
	SUM(
		CASE
			WHEN net_sale >= 700000 THEN net_sale
			ELSE 0
		END
	) AS net_sales_700k
FROM
	t_dwd_hyper
GROUP BY
	ds
;

WITH
	t_dwd AS (
		SELECT
			PERIOD,
			ORDER_DATE_POS_RECORDED         AS ds,
			PHONE_NUMBER                    AS byr_id,
			ORDER_ID,
			SUM(COALESCE(gmv, 0))           AS gmv,
			SUM(SUM(COALESCE(gmv, 0))) OVER (
				PARTITION BY
					PERIOD,
					ORDER_DATE_POS_RECORDED,
					PHONE_NUMBER
			) AS gmv_byr_base
		FROM
			loutruongdataplatform1.loutruong_dwd.tet
		WHERE
			1 = 1
			-- AND (
			-- 	ORDER_DATE_POS_RECORDED BETWEEN '2024-01-08' AND '2024-02-09'
			-- 	OR ORDER_DATE_POS_RECORDED BETWEEN '2024-12-27' AND '2025-01-28'
			-- ) --<< Time range of the game time (33 days)
			AND (
				ORDER_DATE_POS_RECORDED BETWEEN '2023-12-27' AND '2024-02-25'
				OR ORDER_DATE_POS_RECORDED BETWEEN '2024-12-15' AND '2025-02-13'
			)
			AND CHANNEL_ID IN (0021)
		GROUP BY
			PERIOD,
			ORDER_DATE_POS_RECORDED,
			PHONE_NUMBER,
			ORDER_ID
	)
SELECT
	period,
	ds,
	COUNT(DISTINCT byr_id)   AS byr_cnt,
	COUNT(DISTINCT order_id) AS ord_cnt,
	SUM(COALESCE(gmv, 0))    AS gmv,
	COUNT(
		DISTINCT CASE
			WHEN gmv >= 500000 THEN byr_id
			ELSE NULL
		END
	) AS byr_cnt_500k,
	COUNT(
		DISTINCT CASE
			WHEN gmv >= 500000 THEN order_id
			ELSE NULL
		END
	) AS ord_cnt_500k,
	SUM(
		CASE
			WHEN gmv >= 500000 THEN gmv
			ELSE 0
		END
	) AS gmv_500k,
	COUNT(
		DISTINCT CASE
			WHEN gmv >= 600000 THEN byr_id
			ELSE NULL
		END
	) AS byr_cnt_600k,
	COUNT(
		DISTINCT CASE
			WHEN gmv >= 600000 THEN order_id
			ELSE NULL
		END
	) AS ord_cnt_600k,
	SUM(
		CASE
			WHEN gmv >= 600000 THEN gmv
			ELSE 0
		END
	) AS gmv_600k,
	COUNT(
		DISTINCT CASE
			WHEN gmv >= 700000 THEN byr_id
			ELSE NULL
		END
	) AS byr_cnt_700k,
	COUNT(
		DISTINCT CASE
			WHEN gmv >= 700000 THEN order_id
			ELSE NULL
		END
	) AS ord_cnt_700k,
	SUM(
		CASE
			WHEN gmv >= 700000 THEN gmv
			ELSE 0
		END
	) AS gmv_700k
FROM
	t_dwd
GROUP BY
	period,
	ds
ORDER BY
	period,
	ds
;

WITH
	t_dwd AS (
		SELECT
			*
		FROM
			(
				SELECT
					CASE
						WHEN LOWER(is_retargeting) IN ('true') THEN 'and_event_non_organic_retargeting'
						ELSE 'and_event_non_organic'
					END AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_non_organic_androids
				UNION ALL
				SELECT
					CASE
						WHEN LOWER(is_retargeting) IN ('true') THEN 'ios_event_non_organic_retargeting'
						ELSE 'ios_event_non_organic'
					END AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_non_organic_ios
				UNION ALL
				SELECT
					'and_event_organic' AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_androids
				UNION ALL
				SELECT
					'ios_event_organic' AS table_name,
					*
				FROM
					bigc_tracking_db.bigc_tracking.in_app_event_organic_ios
			)
		WHERE
			1 = 1
			AND (
				event_time BETWEEN '2024-12-15 00:00:00+07' AND '2025-02-13 23:59:59+07'
			)
			AND LOWER(is_primary_attribution) = 'true'
			AND LOWER(event_name) IN ('game_1107.010')
		LIMIT
			10
	)
SELECT
	*
FROM
	t_dwd
LIMIT
	10
;