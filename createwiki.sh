#!/usr/bin/env bash

# Exit on failure to prevent cascading failures
set -o errexit
# Due to the use of a config file, undeclared variables are not preferable
#set -o nounset
# Grab the error codes from mysqldump
set -o pipefail

# Determine the location the script is located, as this folder also contains the other installation files
# Source: http://stackoverflow.com/a/246128/6422957
INSTALLERDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ $# -lt 4 ]; then
	echo "Not enough arguments supplied. ($# given, 4 needed) Displaying help instead:"
	echo "This script adds a new wiki to a Wiki family."
	echo "This script only works with MySQL, MariaDB or PostgreSQL as database server."
	echo "DO NOT run this script with direct user input! It opens up an SQL injection vulnerability!"
	echo "Arguments:"
	echo '$1 - Database name of the new wiki.'
	echo '$2 - Name of the new wiki.'
	echo '$3 - Language code of the new wiki.'
	echo '$4 - The config directory.'
	echo '$5 - (optional) The tags applying to this wiki. These are comma separated. Set to a single comma to ignore.'
	echo '$6 - (optional) location to the template.sql file. If TEMPLATEWIKIDBNAME is specified in family.conf, this database will be used instead.'
	exit 1
fi

TEMPLATEPATH="$INSTALLERDIR/template.sql"

if [ $# -gt 5 ]; then
	TEMPLATEPATH="$6"
fi

if [ ! -f "$INSTALLERDIR/family.conf" ]; then
	echo "Cannot find the configuration file in $INSTALLERDIR/family.conf"
	echo "This file is needed to access the database"
	exit 1
fi

source "$INSTALLERDIR/family.conf"

# Set DBTYPE to mysql in case mariadb is used
if [ -z "$DBTYPE" ] || [ "$DBTYPE" == "mariadb" ]; then
	DBTYPE="mysql"
elif [ "$DBTYPE" != "mysql" ] && [ "$DBTYPE" != "postgres" ]; then
	echo "Cannot run this installer with this choice of database server ($DBTYPE)."
fi

echo "$1|$2|$3" >> "$4/dblists/tags/all.dblist"

if ! grep -xq ${3} "$4/langlist"; then
    echo "$3" >> "$4/langlist"
    echo "Added $3 to the list of languages ($4/langlist) as it was not yet in there."
fi

if [ -z "$DBUSER" ] && [ -z "$INSTALLDBUSER" ]; then
	echo "The database user is not set in the config file!"
	echo "DBUSER or INSTALLDBUSER must be set to use this script."
	exit 1
fi

if [ -z "$DBPASS" ] && [ -z "$INSTALLDBPASS" ]; then
	echo "The database password is not set in the config file!"
	echo "DBPASS or INSTALLDBPASS must be set to use this script."
	exit 1
fi

if [ -z "$INSTALLDBUSER" ]; then
	INSTALLDBUSER="$DBUSER"
fi

if [ -z "$INSTALLDBPASS" ]; then
	INSTALLDBPASS="$DBPASS"
fi

if [ -z "$DBSERVER" ]; then
	DBSERVER='localhost'
fi

# Only set this if DBTYPE is confirmed to be postgres
if [ "$DBTYPE" == "postgres" ]; then
	if [ -z "$DBPORT" ]; then
		DBPORT=5432
	fi
	if [ -z "$DBSCHEMA" ]; then
		DBSCHEMA='mediawiki'
	fi
fi

if [ "$DBTYPE" == "mysql" ]; then

	if [ ! -z "$TEMPLATEWIKIDBNAME" ]; then
		# To import from an existing database, you'll need to export it first
		mysqldump ${TEMPLATEWIKIDBNAME} --user="$INSTALLDBUSER" --password="$INSTALLDBPASS" --host="$DBSERVER" > "$TEMPLATEPATH"
		# Create the new database
		mysqladmin CREATE $1 --user="$INSTALLDBUSER" --password="$INSTALLDBPASS" --host="$DBSERVER"
	fi

	mysql ${1} --user="$INSTALLDBUSER" --password="$INSTALLDBPASS" --host="$DBSERVER" < "$TEMPLATEPATH"

	# Remove the exported file if it was created by this script
	if [ ! -z "$TEMPLATEWIKIDBNAME" ]; then
		rm "$TEMPLATEPATH"
	fi

elif [ "$DBTYPE" == "postgres" ]; then

	ESCAPEDDBSERVER=$(echo "$DBSERVER" | tr : \: | tr \ \\)
	ESCAPEDDBUSER=$(echo "$DBUSER" | tr : \: | tr \ \\)
	ESCAPEDDBPASS=$(echo "$DBPASS" | tr : \: | tr \ \\)
	PGPASSLINE="$ESCAPEDDBSERVER:$DBPORT:$TEMPLATEWIKIDBNAME:$ESCAPEDDBUSER:$ESCAPEDDBPASS"
 	#Create .pgpass file first, to allow working without prompting for password
	echo "$PGPASSLINE" >> ~/.pgpass
	# Required to not have pg_dump ignore the file
	chmod 0600 ~/.pgpass

	# Actual importing
	if [ ! -z "$TEMPLATEWIKIDBNAME" ]; then
		psql --command="CREATE DATABASE $1 WITH TEMPLATE $TEMPLATEWIKIDBNAME OWNER $DBUSER;" --username="$DBPASS" --schema="$DBSCHEMA" --host="$DBSERVER" --port=${DBPORT} --no-password
	else
		psql --dbname=${1} --username="$DBPASS" --schema="$DBSCHEMA" --host="$DBSERVER" --port=${DBPORT} --no-password < "$TEMPLATEPATH"
	fi

	# Remove the password line added by this script
	cp ~/.pgpass ~/.pgpass.tmp
	head -n -1 ~/.pgpass.tmp > ~/.pgpass
	rm -f ~/.pgpass.tmp
fi

# Add the wiki to the specific tag lists
if [ ${5} != ',' ]; then

	IFS=',' read -ra TAGS <<< "$5"
	for tag in "${TAGS[@]}"; do
		echo "$1" >> "$4/dblists/tags/$tag.dblist"
	done
fi

echo 'Wiki creation complete.'
