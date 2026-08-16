/* Обновление витрины f_customer_retention. Скрипт по сути дублирует скрипт первичного заполнения 
  * Отличается тем, что сначала удаляем из таблицы строки с информацией по текущей неделе */
DELETE FROM mart.f_customer_retention
WHERE period_name = 'weekly' AND period_id = date_part('week', '{{ ds }}'::DATE);

WITH t1 AS (
	SELECT 
	    uol.customer_id,
	    uol.item_id,
	    uol.payment_amount,
	    uol.status,
	    'weekly' AS period_name,
	    dc.week_of_year AS period_id
	FROM staging.user_order_log uol
	LEFT JOIN mart.d_calendar dc ON uol.date_time::DATE = dc.date_actual
/* И здесь указываем, что работаем с данными только по текущей неделе */
	WHERE dc.week_of_year = date_part('week', '{{ ds }}'::DATE)  
),
t2 AS (
    SELECT 
        customer_id,
        item_id,
        payment_amount,
        status,
        period_name,
        period_id,
        COUNT(*) OVER (PARTITION BY customer_id, item_id, period_id) AS customer_count        
	FROM t1
),
t3 AS (
SELECT 
    COUNT(DISTINCT CASE WHEN customer_count = 1 THEN customer_id END) AS new_customers_count,
    COUNT(DISTINCT CASE WHEN customer_count > 1 THEN customer_id END) AS returning_customers_count,
    COUNT(DISTINCT CASE WHEN status = 'refunded' THEN customer_id END) AS refunded_customer_count,
    period_name,
    period_id,
    item_id,
    SUM(CASE 
            WHEN customer_count = 1 AND status = 'shipped' THEN payment_amount
            WHEN customer_count = 1 AND status = 'refunded' THEN -payment_amount
            ELSE 0 
        END) AS new_customers_revenue,
    SUM(CASE 
            WHEN customer_count > 1 AND status = 'shipped' THEN payment_amount
            WHEN customer_count > 1 AND status = 'refunded' THEN -payment_amount
            ELSE 0 
        END) AS returning_customers_revenue,
    SUM(CASE WHEN status = 'refunded' THEN 1 ELSE 0 END) AS customers_refunded
FROM t2
GROUP BY period_name, period_id, item_id
)
INSERT INTO mart.f_customer_retention (
    new_customers_count, 
    returning_customers_count, 
    refunded_customer_count,
    period_name,
    period_id, 
    item_id, 
    new_customers_revenue,
    returning_customers_revenue,
    customers_refunded)
SELECT 
    new_customers_count, 
    returning_customers_count, 
    refunded_customer_count,
    period_name,
    period_id, 
    item_id, 
    new_customers_revenue,
    returning_customers_revenue,
    customers_refunded
FROM t3;