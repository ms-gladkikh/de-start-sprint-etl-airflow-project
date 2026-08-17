# de-start-sprint-etl-airflow-project

Файлы проекта:

1. DDL\_project - описание шагов, сделанных на этапе 1 и этапе 2 проекта (включают в себя sql-команды, которые я выполняла в Dbeaver)
2. sprint3.py - первый даг, созданный для обновления данных в таблице staging.user\_order\_log и заполнения таблиц схемы mart (d\_city, d\_customer, d\_item, f\_sales) (1-й этап проекта)
3. mart.d\_city.sql, mart.d\_customer.sql, mart.d\_item.sql, mart.f\_sales.sql - sql-скрипты, которые выполняются внутри первого дага
4. project\_airflow.py - второй даг, созданный для обновления витрины (2-й этап проекта)
5. mart.f\_customer\_retention.sql - sql-скрипт, который выполняется внутри второго дага

