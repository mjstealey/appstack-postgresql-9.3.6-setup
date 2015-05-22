#!/bin/bash

# generate-config-file.sh
# Author: Michael Stealey <michael.j.stealey@gmail.com>

CONFIG_FILE=$1

echo "POSTGRES_PASSWORD: "$(pwgen -c -n -1 16) > $CONFIG_FILE
echo "INITIAL_DATABASE_NAME: "$(pwgen -c -n -1) >> $CONFIG_FILE

exit;