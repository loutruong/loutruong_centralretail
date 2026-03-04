WITH t_dwd AS (
SELECT
	T1.ORDERID AS ORD_ID,
	T1.ORDERNO AS ORD_NO,
	T1.ORDERSTATUS AS ord_header_status,
	t1.ORDER_DATE AS order_created_date,
	T2.PHONE AS USR_ID,
	ROW_NUMBER() OVER(PARTITION BY T2.PHONE ORDER BY t1.ORDER_DATE ASC ) AS ord_num
FROM
	(
	SELECT
		*
	FROM
		DWH.OMS_ORDER_HEADER
	WHERE
		1 = 1
		AND ORDER_DATE BETWEEN TIMESTAMP '2025-07-01 00:00:00.000000' AND TIMESTAMP '2025-07-30 23:59:59.999999'
		AND CREATEDBY IN ('goapp')
) T1
LEFT JOIN (
	SELECT
		*
	FROM
		DWH.OMS_ORDER_CUSTOMER
) T2 ON
	T1.ORDERID = T2.ORDERID
),
t_normalize AS (
SELECT
	USR_ID,
	ord_num_per_usr,
	mean,
	std,
	z_score,
	lower_1,
	upper_1,
	CASE
		WHEN z_score > lower_1
			AND z_score < upper_1 THEN 0
			ELSE 1
		END AS is_outliner
	FROM
		(
		SELECT
			USR_ID,
			ord_num_per_usr,
			AVG(ord_num_per_usr) OVER() AS mean,
			STDDEV(ord_num_per_usr) OVER() AS std,
			(ord_num_per_usr-AVG(ord_num_per_usr) OVER())/ STDDEV(ord_num_per_usr) OVER() AS z_score,
			AVG(ord_num_per_usr) OVER() - STDDEV(ord_num_per_usr) OVER() lower_1,
			AVG(ord_num_per_usr) OVER() + STDDEV(ord_num_per_usr) OVER() upper_1
		FROM
			(
			SELECT
				USR_ID,
				max(ord_num) AS ord_num_per_usr
			FROM
				t_dwd
			GROUP BY
				USR_ID))
)
SELECT
	TO_CHAR(ORDER_CREATED_DATE, 'YYYY-MM') AS mm,
	avg(duration) AS re_purchase_duration
FROM
	(
	SELECT
		t1.*,
		COALESCE(t2.ORD_ID, t1.ORD_ID) AS ORD_ID_next,
		COALESCE(t2.ORD_NO, t1.ORD_NO) AS ORD_NO,
		COALESCE(t2.ORDER_CREATED_DATE, t1.ORDER_CREATED_DATE) AS ORDER_CREATED_DATE_next,
		COALESCE(t2.ORDER_CREATED_DATE, t1.ORDER_CREATED_DATE) - t1.ORDER_CREATED_DATE AS duration
	FROM
		(
		SELECT
			ORD_ID,
			ORD_NO,
			ord_header_status,
			order_created_date,
			USR_ID,
			ord_num,
			to_number(ord_num) + 1 AS ord_num_next
		FROM
			t_dwd
		WHERE
			1 = 1
			AND USR_ID NOT IN (
			SELECT
				USR_ID
			FROM
				t_normalize
			WHERE
				1 = 1
				AND IS_OUTLINER = 1) ) t1
	LEFT JOIN (
		SELECT
			ORD_ID,
			ORD_NO,
			ord_header_status,
			order_created_date,
			USR_ID,
			ord_num
		FROM
			t_dwd
		WHERE
			1 = 1
			AND USR_ID NOT IN (
			SELECT
				USR_ID
			FROM
				t_normalize
			WHERE
				1 = 1
				AND IS_OUTLINER = 1)
) t2 ON
		t1.USR_ID = t2.USR_ID
		AND t1.ORD_NUM_NEXT = t2.ORD_NUM
	ORDER BY
		t1.USR_ID ASC,
		t1.ORD_NUM ASC)
GROUP BY
	TO_CHAR(ORDER_CREATED_DATE, 'YYYY-MM')
;
--
--SELECT
--		COALESCE (ORDERSTATUS,
--	'00_all') AS ORDERSTATUS ,
--	COUNT(DISTINCT ORDERID) AS ord_id_cnt,
--	count(DISTINCT ORDERNO) AS ord_no_cnt,
--	count(*) AS rn_cnt
--FROM
--		DWH.OMS_ORDER_HEADER
--WHERE
--		1 = 1
--	--	AND ORDER_DATE BETWEEN TIMESTAMP '2025-07-30 00:00:00.000000' AND TIMESTAMP '2025-07-30 23:59:59.999999'
--	AND CREATEDDATE BETWEEN TIMESTAMP '2025-07-30 00:00:00.000000' AND TIMESTAMP '2025-07-30 23:59:59.999999'
--	AND CREATEDBY IN ('goapp')
--GROUP BY
--	CUBE (ORDERSTATUS) ;