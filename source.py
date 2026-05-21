import csv
import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime


DB_CONFIG = {
    'dbname': 'dwh',
    'user': 'postgres',
    'password': '3289',
    'host': 'localhost',
    'port': 5433
}


def parse_date(val, col_name=None):
    if not val or val.strip() == '':
        if col_name == 'effective_to_date':
            return datetime(2999, 12, 31).date()
        return None
    try:
        return datetime.strptime(val.strip(), '%Y-%m-%d').date()
    except:
        print("Failed.")
        return None


def load_csv_to_table(csv_path, table_name, schema='rd', encoding='cp1251'):
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    # Читаем заголовки
    with open(csv_path, 'r', encoding=encoding) as f:
        reader = csv.reader(f)
        headers = next(reader)

    rows = []
    with open(csv_path, 'r', encoding=encoding) as f:
        reader = csv.DictReader(f)
        for row in reader:
            converted = []
            for col in headers:
                val = row.get(col, '')
                if 'date' in col.lower():
                    val = parse_date(val, col_name=col)
                elif val == '':
                    val = None
                converted.append(val)
            rows.append(tuple(converted))

    cur.execute(f"TRUNCATE TABLE {schema}.{table_name} RESTART IDENTITY")

    placeholders = ','.join(['%s'] * len(headers))
    insert_sql = f"INSERT INTO {schema}.{table_name} ({','.join(headers)}) VALUES %s"
    execute_values(cur, insert_sql, rows, page_size=1000)

    conn.commit()
    print(f"Таблица {schema}.{table_name} загружена. Записей: {len(rows)}")
    cur.close()
    conn.close()


def refresh_loan_holiday_vitrina():
    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()
    cur.execute("CALL refresh_loan_holiday_info()")
    conn.commit()
    print("Витрина dm.loan_holiday_info обновлена.")
    cur.close()
    conn.close()


if __name__ == "__main__":

    load_csv_to_table('deal_info.csv', 'deal_info')
    load_csv_to_table('product_info.csv', 'product')

    refresh_loan_holiday_vitrina()