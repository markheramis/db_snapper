#!/bin/bash
#==============================================================================
# TITLE:            db_snap.sh
# DESCRIPTION:      script for automating the daily mysql backups on development computer
# AUTHOR:           Mark
# USAGE:            ./db_snap.sh
# CRON:
  # example cron for daily db backup @ 9:15 am
  # min  hr mday month wday command
  # 15   9  *    *     *    /Users/[your user name]/scripts/db_snap.sh

#RESTORE FROM BACKUP
  #$ gunzip < [backupfile.sql.gz] | mysql -u [uname] -p[pass] [dbname]

#==============================================================================
# CUSTOM SETTINGS
#==============================================================================

# Load up .env
set -o allexport
[[ -f .env ]] && source .env
set +o allexport

# include mysql and mysqldump binaries for cron bash user
PATH=$PATH:/usr/local/mysql/bin

#==============================================================================
# METHODS
#==============================================================================

# YYYY-MM-DD
TIMESTAMP=$(date +%F)

function delete_old_backups(){
  echo "Deleting $BACKUP_DIR/*.sql.gz older than $KEEP_BACKUPS_FOR days"
  find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +$KEEP_BACKUPS_FOR -exec rm {} \;
}

function mysql_login(){
  local mysql_login="-u $DB_USERNAME" 
  if [ -n "$DB_PASSWORD" ]; then
    local mysql_login+=" -p$DB_PASSWORD" 
  fi
  echo $mysql_login
}

function database_list(){
  local show_databases_sql="SHOW DATABASES WHERE \`Database\` NOT REGEXP '$IGNORE_DB'"
  echo $(mysql $(mysql_login) -e "$show_databases_sql"|awk -F " " '{if (NR!=1) print $1}')
}

function echo_status(){
  printf '\r'; 
  printf ' %0.s' {0..100} 
  printf '\r'; 
  printf "$1"'\r'
}

function backup_database(){
    mkdir $BACKUP_DIR/$TIMESTAMP
    backup_file="$BACKUP_DIR/$TIMESTAMP/$database.sql.gz" 
    output+="$database => $backup_file\n"
    echo_status "...backing up $count of $total databases: $database"
    $(mysqldump $(mysql_login) $database | gzip -9 > $backup_file)
}

function backup_databases(){
  local databases=$(database_list)
  local total=$(echo $databases | wc -w | xargs)
  local output=""
  local count=1
  for database in $databases; do
    backup_database
    local count=$((count+1))
  done
  echo -ne $output | column -t
}

function hr(){
  printf '=%.0s' {1..100}
  printf "\n"
}

#==============================================================================
# RUN SCRIPT
#==============================================================================
delete_old_backups
hr
backup_databases
hr
printf "All backed up!\n\n"