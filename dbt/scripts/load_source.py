import argparse
import csv
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

import clickhouse_connect

COLUMNS = {
    'transaction_time': 'DateTime', 'merch': 'String', 'cat_id': 'String',
    'amount': 'Float64', 'name_1': 'String', 'name_2': 'String',
    'gender': 'String', 'us_state': 'String', 'lat': 'Float64', 'lon': 'Float64',
    'merchant_lat': 'Float64', 'merchant_lon': 'Float64', 'target': 'UInt8',
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--csv', type=Path, default=Path('../../kaffka_hw02/data/train.csv'))
    args = parser.parse_args()
    if not args.csv.is_file():
        parser.error('Pass --csv /path/to/train.csv from teta-ml-1-2025.')
    with args.csv.open(newline='', encoding='utf-8-sig') as stream:
        reader = csv.DictReader(stream)
        missing = set(COLUMNS) - set(reader.fieldnames or [])
        if missing:
            parser.error(f'Missing required columns: {sorted(missing)}')
        row_count = sum(1 for _ in reader)
    if not row_count:
        parser.error('Empty CSV is not a valid homework dataset')
    with args.csv.open('rb') as stream:
        checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
    client = clickhouse_connect.get_client(
        host=os.getenv('CLICKHOUSE_HOST', '127.0.0.1'),
        port=int(os.getenv('CLICKHOUSE_PORT', '18124')),
        username=os.getenv('CLICKHOUSE_USER', 'default'),
        password=os.getenv('CLICKHOUSE_PASSWORD', ''),
    )
    client.command('CREATE DATABASE IF NOT EXISTS transactions_db')
    ddl = ', '.join(f'{name} {kind}' for name, kind in COLUMNS.items())
    client.command(f'CREATE TABLE IF NOT EXISTS transactions_db.transactions ({ddl}) '
                   'ENGINE = MergeTree ORDER BY (transaction_time, us_state)')
    actual = client.query('SELECT count() FROM transactions_db.transactions').first_row[0]
    if actual:
        raise SystemExit(f'Source contains {actual} rows and was kept unchanged. '
                         'Skip make load when using an existing source.')
    client.command('CREATE TABLE IF NOT EXISTS transactions_db.transactions_load '
                   'AS transactions_db.transactions')
    client.command('TRUNCATE TABLE transactions_db.transactions_load')
    with args.csv.open(newline='', encoding='utf-8-sig') as stream:
        batch = []
        for line, row in enumerate(csv.DictReader(stream), start=2):
            values = []
            for name, kind in COLUMNS.items():
                value = row[name]
                if kind == 'DateTime':
                    value = datetime.fromisoformat(value).replace(tzinfo=timezone.utc)
                elif kind == 'Float64':
                    value = float(value)
                elif kind == 'UInt8':
                    value = int(value)
                    if value not in (0, 1):
                        raise ValueError(f'Invalid target at CSV line {line}')
                values.append(value)
            batch.append(values)
            if len(batch) == 25000:
                client.insert('transactions_db.transactions_load', batch, column_names=list(COLUMNS))
                batch = []
        if batch:
            client.insert('transactions_db.transactions_load', batch, column_names=list(COLUMNS))
    loaded = client.query('SELECT count() FROM transactions_db.transactions_load').first_row[0]
    if loaded != row_count:
        raise RuntimeError(f'Row count mismatch: {loaded} != {row_count}')
    client.command('EXCHANGE TABLES transactions_db.transactions AND transactions_db.transactions_load')
    client.command('DROP TABLE transactions_db.transactions_load')
    summary = client.query('SELECT count() AS rows, sum(target) AS fraud_rows, '
                           'min(transaction_time) AS min_time, max(transaction_time) AS max_time, '
                           'uniqExact(cat_id) AS categories, uniqExact(us_state) AS states '
                           'FROM transactions_db.transactions').first_item
    provenance = {'source': 'https://www.kaggle.com/competitions/teta-ml-1-2025/data',
                  'csv': str(args.csv), 'sha256': checksum, **summary}
    print(json.dumps(provenance, indent=2, default=str))


if __name__ == '__main__':
    main()
