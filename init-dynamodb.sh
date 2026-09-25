#!/bin/bash

echo "Initializing DynamoDB tables..."

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
ENDPOINT="http://localhost:4566"
REGION="eu-central-1"

# List of tables managed by this init script
EXPECTED_TABLES=(
  "moni_users"
  "moni_refresh_tokens"
  "moni_categories"
  "moni_households"
  "moni_entries"
  "moni_verification_codes"
  "moni_household_invitations"
)

delete_unknown_tables() {
  echo "Checking for unknown tables to remove..."
  EXISTING_TABLES=$(aws --endpoint-url=$ENDPOINT --region $REGION \
    dynamodb list-tables --query "TableNames[]" --output text 2>/dev/null)

  for TABLE in $EXISTING_TABLES; do
    KNOWN=false
    for EXPECTED in "${EXPECTED_TABLES[@]}"; do
      if [ "$TABLE" = "$EXPECTED" ]; then
        KNOWN=true
        break
      fi
    done
    if [ "$KNOWN" = false ]; then
      echo "Removing unknown table: $TABLE"
      aws --endpoint-url=$ENDPOINT --region $REGION \
        dynamodb delete-table --table-name "$TABLE" > /dev/null
      echo "Removed: $TABLE"
    fi
  done
  echo "Unknown table cleanup complete."
}

delete_unknown_tables

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

# moni_users
create_table_if_not_exists "moni_users" \
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

# moni_refresh_tokens
create_table_if_not_exists "moni_refresh_tokens" \
  --key-schema AttributeName=tokenId,KeyType=HASH \
  --attribute-definitions \
    AttributeName=tokenId,AttributeType=S \
    AttributeName=userId,AttributeType=S \
    AttributeName=tokenPrefix,AttributeType=S \
  --global-secondary-indexes '[
    {
      "IndexName": "userId-index",
      "KeySchema": [{"AttributeName": "userId", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    },
    {
      "IndexName": "tokenPrefix-index",
      "KeySchema": [{"AttributeName": "tokenPrefix", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --billing-mode PAY_PER_REQUEST

# moni_categories
create_table_if_not_exists "moni_categories" \
  --key-schema AttributeName=categoryId,KeyType=HASH \
  --attribute-definitions \
    AttributeName=categoryId,AttributeType=S \
    AttributeName=ownerKey,AttributeType=S \
  --global-secondary-indexes '[
    {
      "IndexName": "ownerKey-index",
      "KeySchema": [{"AttributeName": "ownerKey", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --billing-mode PAY_PER_REQUEST

# Seed global default categories (ownerKey = "global", isDefault = true)
echo "Seeding global default categories..."
NOW=$(date +%s)
for ROW in \
  "00000000-0000-0000-0000-000000000001|Salary|💼|#1D9E75|INCOME" \
  "00000000-0000-0000-0000-000000000002|Rent|🏠|#D85A30|EXPENSE" \
  "00000000-0000-0000-0000-000000000003|Energy|🔥|#EF9F27|EXPENSE" \
  "00000000-0000-0000-0000-000000000004|Groceries|🛒|#D4537E|EXPENSE" \
  "00000000-0000-0000-0000-000000000005|Transport|🚗|#BA7517|EXPENSE" \
  "00000000-0000-0000-0000-000000000006|Clothing|👕|#F0997B|EXPENSE" \
  "00000000-0000-0000-0000-000000000007|Subscription|📺|#AFA9EC|EXPENSE" \
  "00000000-0000-0000-0000-000000000008|Other|❓|#D3D1C7|EXPENSE" \
  "00000000-0000-0000-0000-000000000009|Stocks|📈|#7F77DD|INVESTMENT" \
  "00000000-0000-0000-0000-000000000010|Savings|🏦|#534AB7|INVESTMENT"
do
  IFS='|' read -r ID NAME EMOJI COLOR TYPE <<< "$ROW"
  # Only seed if the item doesn't already exist
  EXISTING=$(aws --endpoint-url=$ENDPOINT --region $REGION dynamodb get-item \
    --table-name moni_categories \
    --key "{\"categoryId\": {\"S\": \"$ID\"}}" 2>&1)
  if echo "$EXISTING" | grep -q '"Item"'; then
    echo "Category $NAME already exists, skipping."
  else
    aws --endpoint-url=$ENDPOINT --region $REGION dynamodb put-item \
      --table-name moni_categories \
      --item "{
        \"categoryId\": {\"S\": \"$ID\"},
        \"ownerKey\":   {\"S\": \"global\"},
        \"name\":       {\"S\": \"$NAME\"},
        \"emoji\":      {\"S\": \"$EMOJI\"},
        \"color\":      {\"S\": \"$COLOR\"},
        \"type\":       {\"S\": \"$TYPE\"},
        \"isDefault\":  {\"BOOL\": true},
        \"createdAt\":  {\"N\": \"$NOW\"}
      }"
    echo "Seeded: $NAME"
  fi
done
echo "Global default categories seeded."

# moni_households
create_table_if_not_exists "moni_households" \
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

# moni_entries
create_table_if_not_exists "moni_entries" \
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

# moni_verification_codes
create_table_if_not_exists "moni_verification_codes" \
  --key-schema AttributeName=code,KeyType=HASH \
  --attribute-definitions \
    AttributeName=code,AttributeType=S \
  --billing-mode PAY_PER_REQUEST

# moni_household_invitations
create_table_if_not_exists "moni_household_invitations" \
  --key-schema AttributeName=invitationId,KeyType=HASH \
  --attribute-definitions \
    AttributeName=invitationId,AttributeType=S \
    AttributeName=invitedEmail,AttributeType=S \
    AttributeName=householdId,AttributeType=S \
  --global-secondary-indexes '[
    {
      "IndexName": "invitedEmail-index",
      "KeySchema": [{"AttributeName": "invitedEmail", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    },
    {
      "IndexName": "householdId-index",
      "KeySchema": [{"AttributeName": "householdId", "KeyType": "HASH"}],
      "Projection": {"ProjectionType": "ALL"}
    }
  ]' \
  --billing-mode PAY_PER_REQUEST

echo "All tables initialized."
aws --endpoint-url=$ENDPOINT --region $REGION dynamodb list-tables
