#!/bin/bash

echo "Starting DynamoDB Local..."

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=eu-central-1

# Persist database files to /data so data survives add-on restarts
DATA_DIR=/data/dynamodb
mkdir -p "$DATA_DIR"

# Start DynamoDB Local — same as the original image entrypoint but with
# -dbPath instead of -inMemory so data persists across restarts,
# and -port 4566 to match what the API expects.
cd /home/dynamodblocal && java -jar DynamoDBLocal.jar \
    -port 4566 \
    -dbPath "$DATA_DIR" \
    -sharedDb &
DYNAMO_PID=$!

echo "Waiting for DynamoDB Local to be ready..."

until curl -s -X POST http://localhost:4566 \
    -H "Content-Type: application/x-amz-json-1.0" \
    -H "X-Amz-Target: DynamoDB_20120810.ListTables" \
    -H "Authorization: AWS4-HMAC-SHA256 Credential=test/20000101/eu-central-1/dynamodb/aws4_request, SignedHeaders=host, Signature=test" \
    -d '{}' | grep -q "TableNames" > /dev/null 2>&1; do
    echo "DynamoDB Local not ready yet, retrying in 2s..."
    sleep 2
done

echo "DynamoDB Local is up. Running idempotent table initialization..."
/init-dynamodb.sh
echo "Initialization complete."

wait $DYNAMO_PID
