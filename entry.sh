#!/usr/bin/env bash

set -e

[ "$DEBUG" == 'true' ] && set -x

# Check that MONGO variables are defined
if [ -z "${MONGO_PORT_27017_TCP_ADDR}" -a -z "$DB_URI" ]; then
    echo "You must link this container with MONGO or define DB_URI"
    exit 1
fi

# Check that SMTP variables are defined
if [ -z "${SMTP_PORT_587_TCP_ADDR}" -a -z "$SMTP_HOST" ]; then
    echo "You must link this container with SMTP or define SMTP_HOST"
    exit 1
fi

# Alias SMTP variables
if [ -z "$SMTP_HOST" ]; then
    export SMTP_HOST="${SMTP_PORT_587_TCP_ADDR:-localhost}"
    export SMTP_PORT="${SMTP_PORT_587_TCP_PORT:-587}"
    echo "$(basename $0) >> Set SMTP_HOST=$SMTP_HOST, SMTP_PORT=$SMTP_PORT" 
fi

# Wait for SMTP to be available
while ! exec 6<>/dev/tcp/${SMTP_HOST}/${SMTP_PORT}; do
    echo "$(date) - waiting to connect to SMTP at ${SMTP_HOST}:${SMTP_PORT}"
    sleep 1
done

exec 6>&-
exec 6<&-

# Create a DB_URI from linked container. See variables above.
if [ -z "$DB_URI" ]; then
    export DB_URI="mongodb://${MONGO_PORT_27017_TCP_ADDR:-localhost}:${MONGO_PORT_27017_TCP_PORT:-27017}/strider"
    echo 'export DB_URI="mongodb://${MONGO_PORT_27017_TCP_ADDR:-localhost}:${MONGO_PORT_27017_TCP_PORT:-27017}/strider"' > $HOME/.bashrc
    echo "$(basename $0) >> Set DB_URI=$DB_URI"
fi

# Extract port / host for testing below
MONGO_HOST="$(echo ${DB_URI} | cut -d/ -f3 | cut -d \: -f1)"
MONGO_PORT="$(echo ${DB_URI} | cut -d/ -f3 | cut -d \: -f2)"

# Wait for Mongo to be available
while ! exec 6<>/dev/tcp/${MONGO_HOST}/${MONGO_PORT}; do
    echo "$(date) - waiting to connect to MONGO at ${MONGO_HOST}:${MONGO_PORT}"
    sleep 1
done

exec 6>&-
exec 6<&-

# Update npm cache if no modules exist
if [ ! -d "${STRIDER_HOME}/node_modules" ]; then
    echo "$(basename $0) >> Copying node_modules from cache..."
    mkdir -p ${STRIDER_HOME}/node_modules
    cp -r --preserve=mode,timestamps,links,xattr ${STRIDER_SRC}/node_modules.cache/* ${STRIDER_HOME}/node_modules/
fi

# Create admin user if variables defined
if [ ! -z "$STRIDER_ADMIN_EMAIL" -a ! -z "$STRIDER_ADMIN_PASSWORD" ]; then
    echo "$(basename $0) >> Running addUser"
    strider addUser --email $STRIDER_ADMIN_EMAIL --password $STRIDER_ADMIN_PASSWORD --admin true
    echo "$(basename $0) >> Created Admin User: $STRIDER_ADMIN_EMAIL, Password: $STRIDER_ADMIN_PASSWORD"
fi

echo "Exec'ing command $@"
exec "$@"
