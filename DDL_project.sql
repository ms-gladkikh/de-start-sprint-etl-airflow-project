/* Этап 1 проекта. 
 * Для того, чтобы смог отработать первый даг (sprint3.py), добавила в две таблицы столбец status */
ALTER TABLE staging.user_order_log ADD COLUMN status VARCHAR(20) DEFAULT 'shipped'; 
ALTER TABLE mart.f_sales ADD COLUMN status VARCHAR(20) DEFAULT 'shipped'; 

/* Затем с помощью утилиты curl загрузила на свой компьютер файл user_order_log.csv и, используя встроенную в DBeaver
 * функцию "Импорт данных", наполнила таблицу staging.user_order_log первичными данными из загруженного файла.
 * После чего удалила лишний создавшийся столбец: */
ALTER TABLE staging.user_order_log DROP COLUMN id; 

/* В даге sprint3.py внесла свои данные в двух строчках:
 * nickname = 'gladkikhms'
 * cohort = '18'
 * после чего запустила его на выполнение. Даг добавил данные из файла user_order_log_inc.csv в staging.user_order_log,
 * а также заполнил таблицы схемы mart (d_city, d_customer, d_item, f_sales) . Для этого он выполнял запросы из файлов 
* mart.d_city.sql, mart.d_customer.sql, mart.d_item.sql, mart.f_sales.sql */

/* Этап 2 проекта. 
   Создание витрины f_customer_retention */
DROP TABLE IF EXISTS mart.f_customer_retention;
CREATE TABLE mart.f_customer_retention (
    id BIGINT GENERATED ALWAYS AS IDENTITY NOT NULL, 
    new_customers_count INTEGER NOT NULL, 
    returning_customers_count INTEGER NOT NULL, 
    refunded_customer_count INTEGER NOT NULL,
    period_name VARCHAR(20) NOT NULL,
    period_id INTEGER NOT NULL, 
    item_id INTEGER NOT NULL, 
    new_customers_revenue NUMERIC(14, 2) NOT NULL,
    returning_customers_revenue NUMERIC(14, 2) NOT NULL,
    customers_refunded INTEGER NOT NULL
);

COMMENT ON COLUMN mart.f_customer_retention.id IS 'Идентификатор записи';
COMMENT ON COLUMN mart.f_customer_retention.new_customers_count IS 'Кол-во новых клиентов (тех, которые сделали только один заказ за рассматриваемый промежуток времени)';
COMMENT ON COLUMN mart.f_customer_retention.returning_customers_count IS 'Кол-во вернувшихся клиентов (тех, которые сделали несколько заказов за рассматриваемый промежуток времени)';
COMMENT ON COLUMN mart.f_customer_retention.refunded_customer_count IS 'Кол-во клиентов, оформивших возврат за рассматриваемый промежуток времени';
COMMENT ON COLUMN mart.f_customer_retention.period_name IS 'Название периода (weekly)';
COMMENT ON COLUMN mart.f_customer_retention.period_id IS 'Идентификатор периода (номер недели или номер месяца)';
COMMENT ON COLUMN mart.f_customer_retention.item_id IS 'Идентификатор категории товара';
COMMENT ON COLUMN mart.f_customer_retention.new_customers_revenue IS 'Доход с новых клиентов';
COMMENT ON COLUMN mart.f_customer_retention.returning_customers_revenue IS 'Доход с вернувшихся клиентов';
COMMENT ON COLUMN mart.f_customer_retention.customers_refunded IS 'Количество возвратов клиентов';

/* Первичное заполнение витрины f_customer_retention данными из staging.user_order_log и вспомогательной таблицы mart.d_calendar */
WITH t1 AS (
/* Первый подзапрос выбирает нужные столцы из staging.user_order_log и добавляет столбцы period_name и period_id,
 * для последнего делается объединение с таблицей mart.d_calendar */
	SELECT 
	    uol.customer_id,
	    uol.item_id,
	    uol.payment_amount,
	    uol.status,
	    'weekly' AS period_name,
	    dc.week_of_year AS period_id
	FROM staging.user_order_log uol
	LEFT JOIN mart.d_calendar dc ON uol.date_time::DATE = dc.date_actual
),
t2 AS (
/* Второй подзапрос с помощью оконной функции добавляет к таблице столбец с информацией о том, сколько покупателей заказали этот товар за этот период */
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
/* Третий подзапрос делает все необходимые расчеты */
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
/* Теперь рассчитанные данные загружаются в созданную ранее таблицу mart.f_customer_retention */
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

/* Далее созданный даг из файла project_airflow.py запускается по расписанию (на данный момент в 11:00 каждый понедельник) 
 * и обновляет данные в таблице mart.f_customer_retention - удаляет данные за текущую неделю и загружает новые, 
 * делая все необходимые расчеты по текущей неделе с учетом новых полученных данных . Внутри дага выполняются sql-команды, 
 * записанные в файл mart.f_customer_retention.sql */

