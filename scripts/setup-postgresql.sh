#!/bin/bash

# setup-postgresql.sh
# Author: Michael Stealey <michael.j.stealey@gmail.com>

set -x

###################################
### POSTGRESQL CONFIG VARIABLES ###
###################################

POSTGRESQL_CONFIG_FILE='postgresql-config.yaml'
POSTGRESQL_DATA_DIR='/var/lib/pgsql/9.3/data'
POSTGRESQL_LOGDIR='/var/lib/pgsql/9.3/data/pg_log'
POSTGRESQL_SETUP_LOGDIR='/var/log'
POSTGRESQL_SETUP_LOGFILE="${POSTGRESQL_SETUP_LOGDIR}/pgsql-setup.log"
SECRETS_DIRECTORY='/root/.secret'
SECRETS_FILE="${SECRETS_DIRECTORY}/secrets.yaml"

### FUNCTIONS ###

f_err() {
    echo "$(date '+%Y-%m-%dT%H:%M') - ERROR: $1" | tee $POSTGRESQL_SETUP_LOGFILE
    exit 1
}

f_warn() {
    echo "$(date '+%Y-%m-%dT%H:%M') - $1" | tee $POSTGRESQL_LOGFILE
    exit 0
}

### CREATE CONFIG FILE AND LOAD INTO ENV ###

if [[ -e /conf/$POSTGRESQL_CONFIG_FILE ]] ; then
    echo "*** Importing existing configuration file: /conf/${POSTGRESQL_CONFIG_FILE} ***"
    cp /conf/$POSTGRESQL_CONFIG_FILE /files/$POSTGRESQL_CONFIG_FILE;
else
    echo "*** Generating configuration file: /files/${POSTGRESQL_CONFIG_FILE} ***"
    /scripts/generate-config-file.sh /files/$POSTGRESQL_CONFIG_FILE
    cp /files/$POSTGRESQL_CONFIG_FILE /conf/$POSTGRESQL_CONFIG_FILE;
fi
# Refresh environment variables derived from updated config file
sed -e "s/:[^:\/\/]/=/g;s/$//g;s/ *=/=/g" /files/${POSTGRESQL_CONFIG_FILE} > $SECRETS_DIRECTORY/posgresql-config.sh
while read line; do export $line; done < <(cat $SECRETS_DIRECTORY/posgresql-config.sh)

### POSTGRESQL_LOGFILE AND TESTS ###

if [[ ! -f $POSTGRESQL_SETUP_LOGFILE ]] ; then
    touch $POSTGRESQL_SETUP_LOGFILE || f_warn "Unable to open ${POSTGRESQL_SETUP_LOGFILE}"
    echo "$(date '+%Y-%m-%dT%H:%M') - Logfile opened" >> $POSTGRESQL_SETUP_LOGFILE
fi

if [[ -z $POSTGRES_PASSWORD ]] ; then
    f_err "No user password was generated - is pwgen installed?"
fi

if [[ ! -d $SECRETS_DIRECTORY ]] ; then
    f_err "There are no volumes mounted from the data container"
fi

if [[ -f $SECRETS_FILE ]] ; then
    f_warn "A ${SECRETS_FILE} already exists"
fi

if [ -f "${POSTGRESQL_DATA_DIR}/ibdata1" ] ; then
    f_warn "${POSTGRESQL_DATA_DIR}/ibdata1 file exists"
fi

#################################
### DBDATA.YAML FILE CREATION ###
#################################

if [[ ! -f $SECRETS_FILE ]] ; then
cat << EOF > $SECRETS_FILE
PGSETUP_DATABASE_NAME: $INITIAL_DATABASE_NAME
PGSETUP_POSTGRES_PASSWORD: $POSTGRES_PASSWORD
EOF
else
    f_warn "A ${SECRETS_FILE} already exists"
fi

chmod 600 $SECRETS_FILE || f_warn "Unable to chown ${SECRETS_FILE}"

###################################
### POSTGRESQL SETUP BELOW HERE ###
###################################

#mkdir -p $PGSQL_LOGDIR || f_err "Unable to create log directory"

for file in $POSTGRESQL_SETUP_LOGFILE ; do
    touch $file | tee $POSTGRESQL_SETUP_LOGFILE || f_err "Unable to create ${file}"
    chown postgres:postgres $file || f_err "Unable to chown ${file} to postgres.postgres"
    chmod 0640 $file || f_err "Unable to chmod ${file} to 0640"
done

chown -R postgres:postgres "${POSTGRESQL_DATA_DIR}"
chmod 0700 "${POSTGRESQL_DATA_DIR}"

sudo -u postgres /usr/pgsql-9.3/bin/initdb -D ${POSTGRESQL_DATA_DIR} | tee $POSTGRESQL_SETUP_LOGFILE
sleep 3s
sudo -u postgres /usr/pgsql-9.3/bin/postgres -D ${POSTGRESQL_DATA_DIR} >$POSTGRESQL_SETUP_LOGFILE 2>&1 &
sleep 3s

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
sudo -u postgres echo "host all  all    0.0.0.0/0  md5" >> ${POSTGRESQL_DATA_DIR}/pg_hba.conf | tee $POSTGRESQL_SETUP_LOGFILE

# And add ``listen_addresses`` to ``/etc/postgresql/9.3/main/postgresql.conf``
sudo -u postgres echo "listen_addresses='*'" >> ${POSTGRESQL_DATA_DIR}/postgresql.conf | tee $POSTGRESQL_SETUP_LOGFILE

sudo -u postgres psql -c "CREATE DATABASE \"${INITIAL_DATABASE_NAME}\" ENCODING 'UNICODE' TEMPLATE template0;"  \
        || f_err "Unable to create database ${INITIAL_DATABASE_NAME}"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"${INITIAL_DATABASE_NAME}\" TO postgres;" \
        || f_err "Unable to grant privileges on ${INITIAL_DATABASE_NAME} to postgres"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '${POSTGRES_PASSWORD}';" \
        || f_err "Unable to change password for user postgres"
sudo -u postgres /usr/pgsql-9.3/bin/pg_ctl stop -D ${POSTGRESQL_DATA_DIR} | tee $POSTGRESQL_SETUP_LOGFILE

exit;