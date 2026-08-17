# Даг запускается по расписанию (на данный момент в 11:00 каждый понедельник) 
# и обновляет данные в таблице mart.f_customer_retention - удаляет данные за текущую неделю и загружает новые, 
# делая все необходимые расчеты по текущей неделе с учетом новых полученных данных . 
# Внутри дага выполняются sql-команды, записанные в файл mart.f_customer_retention.sql 
import time
import requests
import json
import pandas as pd

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python_operator import PythonOperator, BranchPythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.hooks.http_hook import HttpHook

http_conn_id = HttpHook.get_connection('http_conn_id')
api_key = http_conn_id.extra_dejson.get('api_key')
base_url = http_conn_id.host

postgres_conn_id = 'postgresql_de'

nickname = 'gladkikhms'
cohort = '18'

headers = {
    'X-Nickname': nickname,
    'X-Cohort': cohort,
    'X-Project': 'True',
    'X-API-KEY': api_key,
    'Content-Type': 'application/x-www-form-urlencoded'
}

args = {
    "owner": "student",
    'email': ['student@example.com'],
    'email_on_failure': False,
    'email_on_retry': False,
# добавила попытки
    'retries': 5
}

business_dt = '{{ ds }}'

with DAG(
        'customer_retention_mart',
        default_args=args,
        description='Dag for update mart.f_customer_retention',
        catchup=True,
        start_date=datetime.today() - timedelta(days=1),
        schedule_interval = "0 11 * * MON"
) as dag:
    update_f_customer_retention = PostgresOperator(
        task_id='update_f_customer_retention',
        postgres_conn_id=postgres_conn_id,
        sql="sql/mart.f_customer_retention.sql",
        parameters={"date": {business_dt}}
    )

update_f_customer_retention