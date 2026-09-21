FROM localstack/localstack:community-archive

# Copy entrypoint and init script
COPY run.sh /run.sh
COPY init-dynamodb.sh /init-dynamodb.sh
RUN chmod +x /run.sh /init-dynamodb.sh

ENTRYPOINT ["/run.sh"]
