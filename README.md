# LocalStack

General-purpose LocalStack add-on providing a local DynamoDB instance.
Shared across multiple apps — each app uses its own table prefix to avoid naming collisions.
Designed to run as a Home Assistant add-on or standalone via Docker Compose.

## Table naming convention

Tables are prefixed by app name: `<appName>_<tableName>`.

| App | Tables |
|---|---|
| personalFinance | `personalFinance_users`, `personalFinance_refresh_tokens`, `personalFinance_categories`, `personalFinance_households`, `personalFinance_entries` |

## Adding tables for a new app

1. Add `create_table_if_not_exists` calls to `init-dynamodb.sh` using your app's prefix
2. Push the change
3. In HA: update the add-on → restart
4. Existing tables are skipped (idempotent); new tables are created

## Standalone (Docker Compose)

```bash
docker-compose up -d
```

DynamoDB endpoint (from host): `http://localhost:4567`

Verify tables:
```bash
docker exec myLocalstack aws dynamodb list-tables \
  --endpoint-url http://localhost:4566 \
  --region eu-central-1
```

> Reach LocalStack from the **host** on port **4567**. Inside the container the AWS CLI targets `localhost:4566`.

Reset (destroys all data):
```bash
docker-compose down -v && docker-compose up -d
```

## Home Assistant add-on

Add this repository URL to HA add-on store, then install **LocalStack**.
Data is persisted to `/data/localstack` and survives restarts.

Port exposed: `4566/tcp` (DynamoDB endpoint).

## WSL2 line-ending fix

If the init script fails on WSL2:
```bash
dos2unix init-dynamodb.sh run.sh
docker-compose restart myLocalstack
```
