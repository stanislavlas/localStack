#!/bin/bash

echo "Initializing DynamoDB tables..."

ENDPOINT="http://localhost:4566"
REGION="eu-central-1"

# DynamoDB HTTP helper — posts a request to the DynamoDB JSON API.
# Usage: dynamo <Target> <JSON body>
dynamo() {
  local TARGET=$1
  local BODY=$2
  curl -sf \
    -X POST "$ENDPOINT" \
    -H "Content-Type: application/x-amz-json-1.0" \
    -H "X-Amz-Target: DynamoDB_20120810.$TARGET" \
    -H "Authorization: AWS4-HMAC-SHA256 Credential=test/20000101/eu-central-1/dynamodb/aws4_request, SignedHeaders=host, Signature=test" \
    -d "$BODY"
}

# ── Table management ──────────────────────────────────────────────────────────

EXPECTED_TABLES=(
  "moni_users"
  "moni_refresh_tokens"
  "moni_categories"
  "moni_households"
  "moni_entries"
  "moni_verification_codes"
  "moni_household_invitations"
  "moni_recurring_entries"
)

delete_unknown_tables() {
  echo "Checking for unknown tables to remove..."
  RESPONSE=$(dynamo "ListTables" '{}')
  # Extract table names — one per line, strip quotes
  EXISTING=$(echo "$RESPONSE" | grep -o '"[^"]*"' | grep -v "TableNames\|LastEvaluatedTableName" | tr -d '"')

  for TABLE in $EXISTING; do
    KNOWN=false
    for EXPECTED in "${EXPECTED_TABLES[@]}"; do
      if [ "$TABLE" = "$EXPECTED" ]; then KNOWN=true; break; fi
    done
    if [ "$KNOWN" = false ]; then
      echo "Removing unknown table: $TABLE"
      dynamo "DeleteTable" "{\"TableName\":\"$TABLE\"}" > /dev/null
      echo "Removed: $TABLE"
    fi
  done
  echo "Unknown table cleanup complete."
}

table_exists() {
  local TABLE_NAME=$1
  RESULT=$(dynamo "DescribeTable" "{\"TableName\":\"$TABLE_NAME\"}" 2>/dev/null)
  echo "$RESULT" | grep -q '"TableName"'
}

create_table() {
  local TABLE_NAME=$1
  local BODY=$2
  echo "Creating table: $TABLE_NAME"
  dynamo "CreateTable" "$BODY" > /dev/null
  echo "Created: $TABLE_NAME"
}

create_table_if_not_exists() {
  local TABLE_NAME=$1
  local BODY=$2
  if table_exists "$TABLE_NAME"; then
    echo "Table already exists, skipping: $TABLE_NAME"
  else
    create_table "$TABLE_NAME" "$BODY"
  fi
}

# ── Tables ────────────────────────────────────────────────────────────────────

delete_unknown_tables

create_table_if_not_exists "moni_users" '{
  "TableName": "moni_users",
  "KeySchema": [{"AttributeName": "userId", "KeyType": "HASH"}],
  "AttributeDefinitions": [
    {"AttributeName": "userId", "AttributeType": "S"},
    {"AttributeName": "email",  "AttributeType": "S"}
  ],
  "GlobalSecondaryIndexes": [{
    "IndexName": "email-index",
    "KeySchema": [{"AttributeName": "email", "KeyType": "HASH"}],
    "Projection": {"ProjectionType": "ALL"}
  }],
  "BillingMode": "PAY_PER_REQUEST"
}'

create_table_if_not_exists "moni_refresh_tokens" '{
  "TableName": "moni_refresh_tokens",
  "KeySchema": [{"AttributeName": "tokenId", "KeyType": "HASH"}],
  "AttributeDefinitions": [
    {"AttributeName": "tokenId",     "AttributeType": "S"},
    {"AttributeName": "userId",      "AttributeType": "S"},
    {"AttributeName": "tokenPrefix", "AttributeType": "S"}
  ],
  "GlobalSecondaryIndexes": [
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
  ],
  "BillingMode": "PAY_PER_REQUEST"
}'

create_table_if_not_exists "moni_categories" '{
  "TableName": "moni_categories",
  "KeySchema": [{"AttributeName": "categoryId", "KeyType": "HASH"}],
  "AttributeDefinitions": [
    {"AttributeName": "categoryId", "AttributeType": "S"},
    {"AttributeName": "ownerKey",   "AttributeType": "S"}
  ],
  "GlobalSecondaryIndexes": [{
    "IndexName": "ownerKey-index",
    "KeySchema": [{"AttributeName": "ownerKey", "KeyType": "HASH"}],
    "Projection": {"ProjectionType": "ALL"}
  }],
  "BillingMode": "PAY_PER_REQUEST"
}'

# ── Seed global default categories ───────────────────────────────────────────
echo "Seeding global default categories..."
NOW=$(date +%s)

seed_category() {
  local ID=$1 NAME=$2 EMOJI=$3 COLOR=$4 TYPE=$5
  # Check if already exists
  EXISTING=$(dynamo "GetItem" "{
    \"TableName\": \"moni_categories\",
    \"Key\": {\"categoryId\": {\"S\": \"$ID\"}}
  }" 2>/dev/null)
  if echo "$EXISTING" | grep -q '"Item"'; then
    echo "Category $NAME already exists, skipping."
    return
  fi
  dynamo "PutItem" "{
    \"TableName\": \"moni_categories\",
    \"Item\": {
      \"categoryId\": {\"S\": \"$ID\"},
      \"ownerKey\":   {\"S\": \"global\"},
      \"name\":       {\"S\": \"$NAME\"},
      \"emoji\":      {\"S\": \"$EMOJI\"},
      \"color\":      {\"S\": \"$COLOR\"},
      \"type\":       {\"S\": \"$TYPE\"},
      \"isDefault\":  {\"BOOL\": true},
      \"createdAt\":  {\"N\": \"$NOW\"}
    }
  }" > /dev/null
  echo "Seeded: $NAME"
}

seed_category "00000000-0000-0000-0000-000000000001" "Salary"       "💼" "#1D9E75" "INCOME"
seed_category "00000000-0000-0000-0000-000000000002" "Rent"         "🏠" "#D85A30" "EXPENSE"
seed_category "00000000-0000-0000-0000-000000000003" "Energy"       "🔥" "#EF9F27" "EXPENSE"
seed_category "00000000-0000-0000-0000-000000000004" "Groceries"    "🛒" "#D4537E" "EXPENSE"
seed_category "00000000-0000-0000-0000-000000000005" "Transport"    "🚗" "#BA7517" "EXPENSE"
seed_category "00000000-0000-0000-0000-000000000006" "Clothing"     "👕" "#F0997B" "EXPENSE"
seed_category "00000000-0000-0000-0000-000000000007" "Subscription" "📺" "#AFA9EC" "EXPENSE"
seed_category "00000000-0000-0000-0000-000000000008" "Other"        "❓" "#D3D1C7" "EXPENSE"
seed_category "00000000-0000-0000-0000-000000000009" "Stocks"       "📈" "#7F77DD" "INVESTMENT"
seed_category "00000000-0000-0000-0000-000000000010" "Savings"      "🏦" "#534AB7" "INVESTMENT"

echo "Global default categories seeded."

create_table_if_not_exists "moni_households" '{
  "TableName": "moni_households",
  "KeySchema": [{"AttributeName": "householdId", "KeyType": "HASH"}],
  "AttributeDefinitions": [
    {"AttributeName": "householdId", "AttributeType": "S"},
    {"AttributeName": "ownerId",     "AttributeType": "S"}
  ],
  "GlobalSecondaryIndexes": [{
    "IndexName": "ownerId-index",
    "KeySchema": [{"AttributeName": "ownerId", "KeyType": "HASH"}],
    "Projection": {"ProjectionType": "ALL"}
  }],
  "BillingMode": "PAY_PER_REQUEST"
}'

create_table_if_not_exists "moni_entries" '{
  "TableName": "moni_entries",
  "KeySchema": [{"AttributeName": "entryId", "KeyType": "HASH"}],
  "AttributeDefinitions": [
    {"AttributeName": "entryId",     "AttributeType": "S"},
    {"AttributeName": "userId",      "AttributeType": "S"},
    {"AttributeName": "householdId", "AttributeType": "S"},
    {"AttributeName": "date",        "AttributeType": "S"}
  ],
  "GlobalSecondaryIndexes": [
    {
      "IndexName": "userId-date-index",
      "KeySchema": [
        {"AttributeName": "userId", "KeyType": "HASH"},
        {"AttributeName": "date",   "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    },
    {
      "IndexName": "householdId-date-index",
      "KeySchema": [
        {"AttributeName": "householdId", "KeyType": "HASH"},
        {"AttributeName": "date",        "KeyType": "RANGE"}
      ],
      "Projection": {"ProjectionType": "ALL"}
    }
  ],
  "BillingMode": "PAY_PER_REQUEST"
}'

create_table_if_not_exists "moni_verification_codes" '{
  "TableName": "moni_verification_codes",
  "KeySchema": [{"AttributeName": "code", "KeyType": "HASH"}],
  "AttributeDefinitions": [
    {"AttributeName": "code", "AttributeType": "S"}
  ],
  "BillingMode": "PAY_PER_REQUEST"
}'

create_table_if_not_exists "moni_household_invitations" '{
  "TableName": "moni_household_invitations",
  "KeySchema": [{"AttributeName": "invitationId", "KeyType": "HASH"}],
  "AttributeDefinitions": [
    {"AttributeName": "invitationId",  "AttributeType": "S"},
    {"AttributeName": "invitedEmail",  "AttributeType": "S"},
    {"AttributeName": "householdId",   "AttributeType": "S"}
  ],
  "GlobalSecondaryIndexes": [
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
  ],
  "BillingMode": "PAY_PER_REQUEST"
}'

create_table_if_not_exists "moni_recurring_entries" '{
  "TableName": "moni_recurring_entries",
  "KeySchema": [{"AttributeName": "recurringId", "KeyType": "HASH"}],
  "AttributeDefinitions": [
    {"AttributeName": "recurringId", "AttributeType": "S"},
    {"AttributeName": "userId",      "AttributeType": "S"}
  ],
  "GlobalSecondaryIndexes": [{
    "IndexName": "userId-index",
    "KeySchema": [{"AttributeName": "userId", "KeyType": "HASH"}],
    "Projection": {"ProjectionType": "ALL"}
  }],
  "BillingMode": "PAY_PER_REQUEST"
}'

echo "All tables initialized."
# Print final table list
dynamo "ListTables" '{}' | grep -o '"[^"]*"' | grep -v "TableNames\|LastEvaluatedTableName" | tr -d '"'
