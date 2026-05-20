#!/bin/sh
#
# Common variables and helper functions for UBinstaller / Batchinstaller.
#

# Path to the installer log file 
LOG_FILE="/var/log/ubinstaller.log"

# Stargazer runtime / defaults
STG_PID_FILE="/var/run/stargazer.pid"
STG_WAIT_TIMEOUT=120
STG_DEFAULT_PORT="5555"
STG_DEFAULT_LOGIN="admin"
STG_DEFAULT_PASS="123456"

# MySQL defaults (MYSQL_PASSWD is set by the main installer script)
MYSQL_BIN="/usr/local/bin/mysql"
MYSQL_USER="root"
MYSQL_DB="stg"

# Loads a SQL dump file into MySQL.
# Usage:
#   load_sql_dump <sql_file>
#   load_sql_dump <sql_file> <db>
load_sql_dump() {
    _sql_file="$1"
    _db="$2"
    if [ -n "${_db}" ]; then
        "${MYSQL_BIN}" -u "${MYSQL_USER}" --password="${MYSQL_PASSWD}" "${_db}" < "${_sql_file}"
    else
        "${MYSQL_BIN}" -u "${MYSQL_USER}" --password="${MYSQL_PASSWD}" < "${_sql_file}"
    fi
}

# Waits until Stargazer PID file appears
# Returns 1 on timeout to avoid hanging the installer indefinitely.
wait_stargazer_start() {
    echo -n "Waiting for Stargazer to start"
    WAIT_COUNT=0
    while [ ! -f "${STG_PID_FILE}" ]; do
        echo -n "."
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -ge ${STG_WAIT_TIMEOUT} ]; then
            echo " timeout!"
            return 1
        fi
    done
    echo " ok"
    sleep 3
    return 0
}

# Waits until Stargazer PID file disappears
wait_stargazer_stop() {
    echo -n "Waiting for Stargazer to stop"
    WAIT_COUNT=0
    while [ -f "${STG_PID_FILE}" ]; do
        echo -n "."
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -ge ${STG_WAIT_TIMEOUT} ]; then
            echo " timeout!"
            return 1
        fi
    done
    echo " ok"
    sleep 1
    return 0
}
