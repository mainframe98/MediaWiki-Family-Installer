#!/usr/bin/env bash

# Exit on failure to prevent cascading failures
set -o errexit
# Due to the use of a config file, undeclared variables are not preferable
#set -o nounset
# Grab the error codes from mysqldump
set -o pipefail

if [ ! hash php 2>/dev/null ]; then
	echo "PHP must be installed to run this installer."
	die 1
fi

# Determine the location the script is located, as this folder also contains the other installation files
# Source: http://stackoverflow.com/a/246128/6422957
INSTALLERDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ $INSTALLERDIR == *' '* ]]; then
	echo "Paths with a space in their name are not processed correctly. Rename the folder containing a space and try again. ($INSTALLERDIR)"
	exit 1
fi

if [ $# -lt 1 ]; then
	echo "Not enough arguments supplied. ($# given, 2 needed) Displaying help instead:"
	echo "This script installs a Wiki family."
	echo "Arguments:"
	echo '$1 - Location of the MediaWiki distribution.'
	echo '$2 - Release of MediaWiki to download: master for the master branch or REL1_XX or wmf/1.XX.0-wmf.X for a specific release.'
	echo '$3 - (optional) config directory, if different from $IP/config.'
	exit 1
fi

if [ ! -d "$1" ]; then
	mkdir "$1"
fi

# Clone the requested branch
git clone --branch="$2" --single-branch https://github.com/wikimedia/mediawiki.git "$1"

# Check if composer is available, if not, download it, else run the installed
if [ ! hash composer 2>/dev/null ]; then
	echo "Composer is not available globally, downloading a local copy now."
	php -r "copy('https://getcomposer.org/installer', '$INSTALLERDIR/composer-setup.php');"
	php composer-setup.php --install-dir=${INSTALLERDIR}
	php -r "unlink('composer-setup.php');"
	# Run composer
	php ${INSTALLERDIR}/composer.phar install --working-dir="$1"
else
	composer install --working-dir="$1"
fi

CONFIGDIR="$1/config"

if [ $# -gt 2 ]; then
	if [[ CONFIGDIR != /* ]]; then
		CONFIGDIR="$1/$3"
	else
		CONFIGDIR="$3"
	fi
fi

if [ ! -d "$CONFIGDIR" ]; then
	mkdir "$CONFIGDIR"
fi

if [[ CONFIGDIR != /* ]]; then
	# Add the config directory to .gitignore, but only if it is in the MediaWiki installation folder
	RELATIVECONFIGDIRPATH=${CONFIGDIR#$1}
	echo -e "\n# MediaWiki configuration folder\n/$RELATIVECONFIGDIRPATH" >> "$1/.gitignore"
	echo "Added $RELATIVECONFIGDIRPATH to $1/.gitignore"
fi

git clone https://github.com/mainframe98/MediaWiki-Family-Configuration-Example.git ${CONFIGDIR}

# Install the Wiki family installer and its installer override
cp "$INSTALLERDIR/familyInstaller.php" "$1/maintenance/familyInstaller.php"
cp "$INSTALLERDIR/familyCliInstaller.php" "$1/mw-config/overrides/familyCliInstaller.php"

if [ ! -f "$INSTALLERDIR/family.conf" ]; then
	echo "Installation is done, however, you still need to install MediaWiki itself. A script to do this has been installed: see maintenance/familyInstaller.php in $1."
	exit 0
else
	echo "Installation is done. Starting MediaWiki installation now."
fi

ADDITIONALPARAM=""

source "$INSTALLERDIR/family.conf"

# Block of default settings to prevent breaking and leaving things in an abyss in between
if [ -z "$CENTRALWIKINAME" ]; then
	CENTRALWIKINAME='Meta wiki'
fi

if [ -z "$CENTRALWIKIDBNAME" ]; then
	CENTRALWIKIDBNAME='metawiki'
fi

if [ -z "$CENTRALWIKILANG" ]; then
	CENTRALWIKILANG='en'
fi

if [ -z "$DBUSER" ]; then
	DBUSER='wikiuser'
fi

if [ -z "$DBPASS" ]; then
	echo 'The database password is not set in the config file!'
	echo 'Could not start MediaWiki installation.'
	exit 1
fi

if [ -z "$INSTALLDBUSER" ]; then
	INSTALLDBUSER=${DBUSER}
fi

if [ -z "$INSTALLDBPASS" ]; then
	INSTALLDBPASS=${DBPASS}
fi

if [ -z "$DBSERVER" ]; then
	DBSERVER='localhost'
fi

# Set DBTYPE to mysql in case mariadb is used
if [ -z "$DBTYPE" ] || [ "$DBTYPE" == "mariadb" ]; then
	DBTYPE='mysql'
fi

# Only set this if DBTYPE is confirmed to be postgres or mssql
if [ "$DBTYPE" == "mssql" ] || [ "$DBTYPE" == "postgresql" ]; then
	if [ "$DBTYPE" == "postgres" ]; then
		if [ -z "$DBPORT" ]; then
			ADDITIONALPARAM="$ADDITIONALPARAM --dbport=5432"
		else
			ADDITIONALPARAM="$ADDITIONALPARAM --dbport=$DBPORT"
		fi
	fi

	if [ -z "$DBSCHEMA" ]; then
		ADDITIONALPARAM="$ADDITIONALPARAM --dbschema=mediawiki"
	else
		ADDITIONALPARAM="$ADDITIONALPARAM --dbschema=$DBSCHEMA"
	fi
fi

# Only set this if DBTYPE is confirmed to be sqlite
if [ "$DBTYPE" == "sqlite" ]; then
	if [ -z "$DBPATH" ]; then
		ADDITIONALPARAM="$ADDITIONALPARAM --dbpath=$1/data"
	else
		DBPATH="${DBPATH/\$IP/$1}"
		ADDITIONALPARAM="$ADDITIONALPARAM --dbpath=$DBPATH"
	fi
fi

if [ -z "$SERVER" ]; then
	SERVER='localhost'
fi

if [ -z "$SCRIPTPATH" ]; then
	SCRIPTPATH='/wiki'
fi

if [ ! -z "$CONFPATH" ]; then
	CONFPATH="${CONFPATH/\$IP/$1}"
	ADDITIONALPARAM="$ADDITIONALPARAM --confpath=$CONFPATH"
fi

if [ ! -z "$MAINPAGECONTENTPATH" ]; then
	MAINPAGECONTENTPATH="${MAINPAGECONTENTPATH/\$IP/$1}"
	if [ -f $MAINPAGECONTENTPATH ]; then
		ADDITIONALPARAM="$ADDITIONALPARAM --mainpagecontentpath=$MAINPAGECONTENTPATH"
	else
		echo "The file with the custom main page content does not exist on the given path ($MAINPAGECONTENTPATH). The default message will be used."
	fi
fi

if [ -z "$TEMPLATEWIKINAME" ]; then
	TEMPLATEWIKINAME='New wiki'
fi

if [ -z "$TEMPLATEWIKILANG" ]; then
	TEMPLATEWIKILANG="$CENTRALWIKILANG"
fi

if [ -z "$TEMPLATEWIKIDBNAME" ]; then
	TEMPLATEWIKIDBNAME='template'
fi

# Install the template first
php $1/maintenance/familyInstaller.php "$TEMPLATEWIKINAME" --dbname=${TEMPLATEWIKIDBNAME} --dbuser="$DBUSER" --dbpass="$DBPASS" --dbserver="$DBSERVER" --installdbuser="$INSTALLDBUSER" --installdbpass="$INSTALLDBPASS" --server="$SERVER" --scriptpath="$SCRIPTPATH" --skipinterwiki --lang=${TEMPLATEWIKILANG} ${ADDITIONALPARAM}

echo "Installation of $TEMPLATEWIKINAME done."

if [ "$DBTYPE" == "mysql" ]; then

	mysqldump ${TEMPLATEWIKIDBNAME} --user="$INSTALLDBUSER" --password="$INSTALLDBPASS" --host="$DBSERVER" > "$INSTALLERDIR/template.sql"
	echo "Exported dump to $INSTALLERDIR/template.sql"

elif [ "$DBTYPE" == "postgres" ]; then

	ESCAPEDDBSERVER=$(echo "$DBSERVER" | tr : \: | tr \ \\)
	ESCAPEDDBUSER=$(echo "$DBUSER" | tr : \: | tr \ \\)
	ESCAPEDDBPASS=$(echo "$DBPASS" | tr : \: | tr \ \\)
	PGPASSLINE="$ESCAPEDDBSERVER:$DBPORT:$TEMPLATEWIKIDBNAME:$ESCAPEDDBUSER:$ESCAPEDDBPASS"
	# Create .pgpass file first, to allow working without prompting for password
	echo "$PGPASSLINE" >> ~/.pgpass
	# Required to not have pg_dump ignore the file
	chmod 0600 ~/.pgpass

	# Actual dumping
	pg_dump ${TEMPLATEWIKIDBNAME} --username="$DBUSER" --schema="$DBSCHEMA" --host="$DBSERVER" --port=${DBPORT} --no-password > "$INSTALLERDIR/template.sql"
	echo "Exported dump to $INSTALLERDIR/template.sql"

	# Remove the password line added by this script
	cp ~/.pgpass ~/.pgpass.tmp
	head -n -1 ~/.pgpass.tmp > ~/.pgpass
	rm -f ~/.pgpass.tmp

elif [ "$DBTYPE" == "sqlite" ]; then
	sqlite3 ${TEMPLATEWIKIDBNAME}.sqlite3 ".dump" > "$INSTALLERDIR/template.sql"

	echo "Exported dump to $INSTALLERDIR/template.sql"
else

	echo "Can't create a dump for template wiki for this choice of database server ($DBTYPE) with this script. You will need to do this manually."
	echo "Continuing installation."

fi

# Move the LocalSettings file for the template wiki to a new name
mv "$1/LocalSettings.php" "$1/LocalSettings.template.php"

# Install the central wiki next
php $1/maintenance/familyInstaller.php "$CENTRALWIKINAME" --dbname=${CENTRALWIKIDBNAME} --dbuser="$DBUSER" --dbpass="$DBPASS" --dbserver="$DBSERVER" --installdbuser="$INSTALLDBUSER" --installdbpass="$INSTALLDBPASS" --server="$SERVER" --scriptpath="$SCRIPTPATH" --lang=${CENTRALWIKILANG} ${ADDITIONALPARAM}
echo "Installation of $CENTRALWIKINAME done."

# Move the LocalSettings file for the central wiki to a new name
mv "$1/LocalSettings.php" "$1/LocalSettings.central.php"

# Link LocalSettings.php to LocalSettings.php in the config directory
ln -s "$CONFIGDIR/LocalSettings.php" "$1/LocalSettings.php"

echo "Installation done."
