FROM amazon/dynamodb-local:latest

USER root

COPY run.sh /run.sh
COPY init-dynamodb.sh /init-dynamodb.sh
RUN chmod +x /run.sh /init-dynamodb.sh

ENTRYPOINT ["/run.sh"]
