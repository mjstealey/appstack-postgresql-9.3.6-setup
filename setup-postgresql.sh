#!/bin/sh

set -x

###############################
### SCRIPT CONFIG VARIABLES ###
###############################

DB_NAME='ICAT'
DB_USER='irods'
DB_PASS=$(pwgen -c -n -1 16)
SECRET_DIR='/root/.secret'
DB_FILE="${SECRET_DIR}/dbdata.yaml"
LOGFILE='/var/log/postgresqldb-setup.log'

##############################
### MYSQL CONFIG VARIABLES ###
##############################

DATADIR='/var/lib/pgsql/9.3/data'
PGSQL_LOGDIR='/var/log/postgresqldb'
PGSQL_LOGFILE="${PGSQL_LOGDIR}/postgresqldb.log"
PGSQL_ERR_LOGFILE="${PGSQL_LOGDIR}/postgresqldb-error.log"
PGSQL_SLO_LOGFILE="${PGSQL_LOGDIR}/postgresqldb-slow.log"

### FUNCTIONS ###

f_err() {
  echo "$(date '+%Y-%m-%dT%H:%M') - ERROR: $1" | tee $LOGFILE
  exit 1
}

f_warn() {
  echo "$(date '+%Y-%m-%dT%H:%M') - $1" | tee $LOGFILE
  exit 0
}

### LOGFILE AND TESTS ###

if [[ ! -f $LOGFILE ]] ; then
  touch $LOGFILE || f_warn "Unable to open ${LOGFILE}"
  echo "$(date '+%Y-%m-%dT%H:%M') - Logfile opened" >> $LOGFILE
fi

if [[ -z $DB_USER ]] ; then
  f_err "No user was added - is this correct?"
fi

if [[ -z $DB_PASS ]] ; then
  f_err "No user password was generated - is pwgen installed?"
fi

if [[ ! -d $SECRET_DIR ]] ; then
  f_err "There are no volumes mounted from the data container"
fi

if [[ -f $DB_FILE ]] ; then
  f_warn "A ${DB_FILE} already exists"
fi

if [ -f "${DATADIR}/ibdata1" ] ; then
  f_warn "${DATADIR}/ibdata1 file exists"
fi

#################################
### DBDATA.YAML FILE CREATION ###
#################################

if [[ ! -f $DB_FILE ]] ; then
cat << EOF > $DB_FILE
---
  database: $DB_NAME
  user: $DB_USER 
  pass: $DB_PASS
EOF
else
  f_warn "A ${DB_FILE} already exists"
fi

chmod 600 $DB_FILE || f_warn "Unable to chown ${DB_FILE}"

##############################
### PGSQL SETUP BELOW HERE ###
##############################

mkdir -p $PGSQL_LOGDIR || f_err "Unable to create log directory"

for file in $PGSQL_ERR_LOGFILE $PGSQL_SLO_LOGFILE $PGSQL_LOGFILE ; do
  touch $file | tee $LOGFILE || f_err "Unable to create ${file}"
  chown postgres:postgres $file || f_err "Unable to chown ${file} to postgres.postgres"
  chmod 0640 $file || f_err "Unable to chmod ${file} to 0640"
done

chown -R postgres:postgres "${DATADIR}"
chmod 0700 "${DATADIR}"

sudo -u postgres /usr/pgsql-9.3/bin/initdb -D ${DATADIR} | tee $PGSQL_LOGFILE
sleep 3s
sudo -u postgres /usr/pgsql-9.3/bin/postgres -D ${DATADIR} >$PGSQL_LOGFILE 2>&1 &
sleep 3s
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';" \
        || f_err "Unable to create user ${DB_USER}"
sudo -u postgres psql -c "CREATE DATABASE \"${DB_NAME}\";"  \
        || f_err "Unable to create database ${DB_NAME}"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO ${DB_USER};" \
        || f_err "Unable to grant privileges on ${DB_NAME} to ${DB_USER}"
sudo -u postgres /usr/pgsql-9.3/bin/pg_ctl stop -D ${DATADIR} | tee $PGSQL_LOGFILE