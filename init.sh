#!/bin/bash
#
# Run the MSSQL database migrations as well as seeding the database

[[ -n "${DEBUG}" ]] && set -o xtrace

readonly GREEN='\033[0;32m'
readonly RESET='\033[0m'
readonly SQLCMD="/opt/mssql-tools/bin/sqlcmd -S ${SERVER} -U sa -P ${SA_PASSWORD}"

set -o nounset
set -o errexit

##############################################################################
# wait for database to come online
# Globals:
#   SQLCMD
#   MIGRATION_TIMEOUT
# Arguments:
#   None
# Returns:
#   None
##############################################################################

wait_for_database() {
    until ${SQLCMD} -l 1 -Q "select getdate()" > /dev/null 2>&1; do
        echo "SqlServer is unavailable - waiting ${MIGRATION_TIMEOUT}..."
        sleep ${MIGRATION_TIMEOUT}
    done

    >&2 echo "SqlServer is up - executing command"
}

##############################################################################
# Create database (dropping if needed) for local development
# Globals:
#   LOCAL_DEVELOPMENT
#   DATABASE
#   SQLCMD
#   GREEN
#   RESET
# Arguments:
#   None
# Returns:
#   None
##############################################################################

create_database() {
    if [[ -n "${LOCAL_DEVELOPMENT:+set}" ]]; then
        echo -e "Creating database ${GREEN}${DATABASE}${RESET}..."
        ${SQLCMD} -Q "DROP DATABASE IF EXISTS ${DATABASE};"
        ${SQLCMD} -Q "CREATE DATABASE ${DATABASE};"
    fi
}

##############################################################################
# Create migration table if needed
# Globals:
#   SQLCMD
#   MIGRATION_TABLE_NAME
#   DATABASE
#   GREEN
#   RESET
# Arguments:
#   None
# Returns:
#   None
##############################################################################
create_migration_table() {
    echo -e "Creating ${GREEN}${MIGRATION_TABLE_NAME}${RESET} table..."

    cat <<SQL > ${MIGRATION_SCRIPT_LOCATION}
CREATE TABLE [dbo].[_Migrations] (
	[ScriptFile] [nvarchar](255) NOT NULL,
	[Hash] [nvarchar](64) NOT NULL,
	[DateApplied] [datetime] NOT NULL

	CONSTRAINT [PK__Migrations] PRIMARY KEY clustered
	(
		[ScriptFile] ASC
	)
)
GO

CREATE INDEX [IX_usd_DateApplied] ON [dbo].[_Migrations]
(
	[DateApplied] ASC
)
GO
SQL

    ${SQLCMD} -d ${DATABASE} -i ${MIGRATION_SCRIPT_LOCATION}
}

##############################################################################
# Run migrations/*.sql scripts
# Globals:
#   MIGRATION_DB_FOLDER
#   MIGRATION_SCRIPT_LOCATION
#   GREEN
#   RESET
# Arguments:
#   None
# Returns:
#   None
##############################################################################
run_migrations() {
    local readonly migrations="${MIGRATION_DB_FOLDER}/migrations"
    local readonly dry_run=$([[ -n "${DRY_RUN:+set}" ]] && echo " [DRY RUN]" || echo "")

    if [[ -d ${migrations} ]] && ls ${migrations}/*.sql 1>/dev/null; then
        echo -e "Preparing migration script from ${GREEN}${migrations}${RESET}..."

        cat << SQL > ${MIGRATION_SCRIPT_LOCATION}
/* Script was generated on $(date -u '+%Y-%m-%d %H:%M:%SZ') */

--LOCK TABLE ONLY "${MIGRATION_TABLE_NAME}" IN ACCESS EXCLUSIVE MODE;

SQL

        for entry in $(ls ${migrations}/*.sql | sort)
        do
            echo -e "Adding migration ${GREEN}${entry}${RESET}"
        
            local readonly name=$(basename ${entry})
            local readonly hash=$(sha1sum ${entry} | cut -f 1 -d ' ')

            cat << SQL >> ${MIGRATION_SCRIPT_LOCATION}

--
-- BEG: $name
--
IF NOT EXISTS (SELECT 1 FROM [${MIGRATION_TABLE_NAME}] WHERE [ScriptFile] = '${name}')
BEGIN
SQL
            if [[ -z "${dry_run}" ]]; then
                cat ${entry} | sed -e 's,^,\t,g' >> ${MIGRATION_SCRIPT_LOCATION}
                cat << SQL >> ${MIGRATION_SCRIPT_LOCATION}

    INSERT INTO [${MIGRATION_TABLE_NAME}] (ScriptFile, Hash, DateApplied) VALUES ('${name}', '${hash}', GETDATE())

SQL
            fi
            cat << SQL >> ${MIGRATION_SCRIPT_LOCATION}
    PRINT N'APPLIED: ${name}${dry_run}'
END
ELSE PRINT N'SKIPPED: ${name} was already applied';
GO
--
-- END: ${name}
--
SQL
        done

        echo "Running migration script..."
        ${SQLCMD} -d ${DATABASE} -i ${MIGRATION_SCRIPT_LOCATION}
    else
        echo -e  "No migrations found at ${GREEN}${migrations}${RESET}"
    fi
}

##############################################################################
# seed local database table if needed
# Globals:
#   LOCAL_DEVELOPMENT
#   MIGRATION_DB_FOLDER
#   DRY_RUN
#   GREEN
#   RESET
# Arguments:
#   None
# Returns:
#   None
##############################################################################
seed_database() {
    local readonly seed="${MIGRATION_DB_FOLDER}/seed"
    local readonly order_file="${seed}/_order"
    local readonly dry_run=$([[ -n "${DRY_RUN:+set}" ]] && echo " [DRY RUN]" || echo "")

    if [[ -n "${LOCAL_DEVELOPMENT:+set}" ]] && [[ -d ${seed} ]] && [[ -f ${order_file} ]]; then
        echo -e "Importing seed data from ${GREEN}${seed}${RESET}..."

        while read name; do
            local readonly table_name=$(echo ${name} | cut -f 1 -d '.')
            local readonly file="${seed}/${name}"

            echo -e "Seeding ${GREEN}${table_name}${RESET} with ${GREEN}${file}${RESET}${dry_run}"
            if [[ -z "${dry_run}" ]]; then
                /opt/mssql-tools/bin/bcp "[${table_name}]" in ${file} -c -t',' -r "\n" -F 2 -S ${SERVER} -d ${DATABASE} -U sa -P ${SA_PASSWORD}
            fi
        done < ${order_file}
    else
        echo -e "No seed data found at ${GREEN}${seed}${RESET}"
    fi
}
wait_for_database
create_database
create_migration_table
run_migrations
seed_database

echo "Done"
