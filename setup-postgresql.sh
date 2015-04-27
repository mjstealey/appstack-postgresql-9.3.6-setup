#!/bin/bash

# setup-postgresql.sh
# Author: Michael Stealey <michael.j.stealey@gmail.com>

set -x

###############################
### SCRIPT CONFIG VARIABLES ###
###############################

DB_NAME=$(pwgen -c -n -1)
POSTGRES_PASS=$(pwgen -c -n -1 16)
SECRET_DIR='/root/.secret'
DB_SECRETS_FILE="${SECRET_DIR}/secrets.yaml"

###################################
### POSTGRESQL CONFIG VARIABLES ###
###################################

DATA_DIR='/var/lib/pgsql/9.3/data'
POSTGRESQL_LOGDIR='/var/lib/pgsql/9.3/data/pg_log'
POSTGRESQL_SETUP_LOGDIR="/var/log"
POSTGRESQL_SETUP_LOGFILE="${POSTGRESQL_SETUP_LOGDIR}/pgsql-setup.log"

### FUNCTIONS ###

f_err() {
  echo "$(date '+%Y-%m-%dT%H:%M') - ERROR: $1" | tee $POSTGRESQL_SETUP_LOGFILE
  exit 1
}

f_warn() {
  echo "$(date '+%Y-%m-%dT%H:%M') - $1" | tee $POSTGRESQL_LOGFILE
  exit 0
}

### POSTGRESQL_LOGFILE AND TESTS ###

if [[ ! -f $POSTGRESQL_SETUP_LOGFILE ]] ; then
  touch $POSTGRESQL_SETUP_LOGFILE || f_warn "Unable to open ${POSTGRESQL_SETUP_LOGFILE}"
  echo "$(date '+%Y-%m-%dT%H:%M') - Logfile opened" >> $POSTGRESQL_SETUP_LOGFILE
fi

if [[ -z $POSTGRES_PASS ]] ; then
  f_err "No user password was generated - is pwgen installed?"
fi

if [[ ! -d $SECRET_DIR ]] ; then
  f_err "There are no volumes mounted from the data container"
fi

if [[ -f $DB_SECRETS_FILE ]] ; then
  f_warn "A ${DB_SECRETS_FILE} already exists"
fi

if [ -f "${DATA_DIR}/ibdata1" ] ; then
  f_warn "${DATA_DIR}/ibdata1 file exists"
fi

#################################
### DBDATA.YAML FILE CREATION ###
#################################

if [[ ! -f $DB_SECRETS_FILE ]] ; then
cat << EOF > $DB_SECRETS_FILE
PGSETUP_DATABASE_NAME: $DB_NAME
PGSETUP_POSTGRES_PASSWORD: $POSTGRES_PASS
EOF
else
  f_warn "A ${DB_SECRETS_FILE} already exists"
fi

chmod 600 $DB_SECRETS_FILE || f_warn "Unable to chown ${DB_SECRETS_FILE}"

###################################
### POSTGRESQL SETUP BELOW HERE ###
###################################

#mkdir -p $PGSQL_LOGDIR || f_err "Unable to create log directory"

for file in $POSTGRESQL_SETUP_LOGFILE ; do
  touch $file | tee $POSTGRESQL_SETUP_LOGFILE || f_err "Unable to create ${file}"
  chown postgres:postgres $file || f_err "Unable to chown ${file} to postgres.postgres"
  chmod 0640 $file || f_err "Unable to chmod ${file} to 0640"
done

chown -R postgres:postgres "${DATA_DIR}"
chmod 0700 "${DATA_DIR}"

sudo -u postgres /usr/pgsql-9.3/bin/initdb -D ${DATA_DIR} | tee $POSTGRESQL_SETUP_LOGFILE
sleep 3s
sudo -u postgres /usr/pgsql-9.3/bin/postgres -D ${DATA_DIR} >$POSTGRESQL_SETUP_LOGFILE 2>&1 &
sleep 3s

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
sudo -u postgres echo "host all  all    0.0.0.0/0  md5" >> ${DATA_DIR}/pg_hba.conf | tee $POSTGRESQL_SETUP_LOGFILE

# And add ``listen_addresses`` to ``/etc/postgresql/9.3/main/postgresql.conf``
sudo -u postgres echo "listen_addresses='*'" >> ${DATA_DIR}/postgresql.conf | tee $POSTGRESQL_SETUP_LOGFILE

#sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';" \
#        || f_err "Unable to create user ${DB_USER}"
sudo -u postgres psql -c "CREATE DATABASE \"${DB_NAME}\";"  \
        || f_err "Unable to create database ${DB_NAME}"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO postgres;" \
        || f_err "Unable to grant privileges on ${DB_NAME} to postgres"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '${POSTGRES_PASS}';" \
        || f_err "Unable to change password for user postgres"
sudo -u postgres /usr/pgsql-9.3/bin/pg_ctl stop -D ${DATA_DIR} | tee $POSTGRESQL_SETUP_LOGFILE