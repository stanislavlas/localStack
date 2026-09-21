#!/bin/bash

echo "Initializing DynamoDB tables..."

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
ENDPOINT="http://localhost:4566"
REGION="eu-central-1"

create_table_if_not_exists() {
  local TABLE_NAME=$1
  shift
  local TABLE_ARGS=("$@")

  RESULT=$(aws --endpoint-url=$ENDPOINT --region $REGION \
    dynamodb describe-table --table-name "$TABLE_NAME" 2>&1)

  if echo "$RESULT" | grep -q "ResourceNotFoundException"; then
    echo "Creating table: $TABLE_NAME"
    aws --endpoint-url=$ENDPOINT --region $REGION \
      dynamodb create-table --table-name "$TABLE_NAME" "${TABLE_ARGS[@]}"
    echo "Created: $TABLE_NAME"
  else
    echo "Table already exists, skipping: $TABLE_NAME"
  fi
}

# personalFinance_users
create_table_if_not_exists "personalFinance_users" \
  --key-schema AttributeName=userId,KeyType=HASH \
  --attribute-definitions \
    AttributeName=userId,AttributeType=S \
    AttributeName=email,AttributeType=S \
  --global-secondary-indexes '[
    {
      "IndexName": "email-index",
      "KeySchema": [{"AttributeName": "email", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --billing-mode PAY_PER_REQUEST

# personalFinance_refresh_tokens
create_table_if_not_exists "personalFinance_refresh_tokens" \
  --key-schema AttributeName=tokenId,KeyType=HASH \
  --attribute-definitions \
    AttributeName=tokenId,AttributeType=S \
    AttributeName=userId,AttributeType=S \
  --global-secondary-indexes '[
    {
      "IndexName": "userId-index",
      "KeySchema": [{"AttributeName": "userId", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --billing-mode PAY_PER_REQUEST

# personalFinance_categories
create_table_if_not_exists "personalFinance_categories" \
  --key-schema AttributeName=categoryId,KeyType=HASH \
  --attribute-definitions \
    AttributeName=categoryId,AttributeType=S \
    AttributeName=userId,AttributeType=S \
    AttributeName=householdId,AttributeType=S \
  --global-secondary-indexes '[
    {
      "IndexName": "userId-index",
      "KeySchema": [{"AttributeName": "userId", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    },
    {
      "IndexName": "householdId-index",
      "KeySchema": [{"AttributeName": "householdId", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --billing-mode PAY_PER_REQUEST

# personalFinance_households
create_table_if_not_exists "personalFinance_households" \
  --key-schema AttributeName=householdId,KeyType=HASH \
  --attribute-definitions \
    AttributeName=householdId,AttributeType=S \
    AttributeName=ownerId,AttributeType=S \
  --global-secondary-indexes '[
    {
      "IndexName": "ownerId-index",
      "KeySchema": [{"AttributeName": "ownerId", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --billing-mode PAY_PER_REQUEST

# personalFinance_entries
create_table_if_not_exists "personalFinance_entries" \
  --key-schema AttributeName=entryId,KeyType=HASH \
  --attribute-definitions \
    AttributeName=entryId,AttributeType=S \
    AttributeName=userId,AttributeType=S \
    AttributeName=householdId,AttributeType=S \
    AttributeName=date,AttributeType=S \
  --global-secondary-indexes '[
    {
      "IndexName": "userId-date-index",
      "KeySchema": [
        {"AttributeName": "userId", "KeyType": "HASH"},
        {"AttributeName": "date", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    },
    {
      "IndexName": "householdId-date-index",
      "KeySchema": [
        {"AttributeName": "householdId", "KeyType": "HASH"},
        {"AttributeName": "date", "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --billing-mode PAY_PER_REQUEST

# personalFinance_verification_codes
create_table_if_not_exists "personalFinance_verification_codes" \
  --key-schema AttributeName=code,KeyType=HASH \
  --attribute-definitions \
    AttributeName=code,AttributeType=S \
  --billing-mode PAY_PER_REQUEST

echo "All tables initialized."
aws --endpoint-url=$ENDPOINT --region $REGION dynamodb list-tables
