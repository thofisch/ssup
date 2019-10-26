FROM mcr.microsoft.com/mssql-tools:latest

# Default environment settings
ENV MIGRATION_TIMEOUT=1s
ENV MIGRATION_TABLE_NAME="_migrations"
ENV MIGRATION_DB_FOLDER="/db"
ENV MIGRATION_SCRIPT_LOCATION="/tmp/script.sql"

WORKDIR /

COPY init.sh ./
RUN chmod +x init.sh
ENTRYPOINT [ "./init.sh" ]
