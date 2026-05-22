import sqlite3
import pandas as pd
import os

DB_PATH = 'data/olist.db'
RAW_DIR = 'data/raw'

TABLE_MAP = {
      'olist_customers_dataset.csv':      'customers',
      'olist_orders_dataset.csv':         'orders',
      'olist_order_items_dataset.csv':    'order_items',
      'olist_order_payments_dataset.csv': 'order_payments',
      'olist_order_reviews_dataset.csv':  'order_reviews',
      'olist_products_dataset.csv':       'products',
      'olist_sellers_dataset.csv':        'sellers',
      'olist_geolocation_dataset.csv':    'geolocation',
      'product_category_name_translation.csv': 'category_translation',
  }
conn = sqlite3.connect(DB_PATH)

for filename, table_name in TABLE_MAP.items():
      path = os.path.join(RAW_DIR, filename)
      df = pd.read_csv(path)
      df.to_sql(table_name, conn, if_exists='replace', index=False)
      print(f'✓ {table_name:30s} {len(df):>8,} rows')

conn.close()
print(f'\nDatabase saved → {DB_PATH}')