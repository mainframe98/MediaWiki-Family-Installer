<?php
/**
 * CLI-based MediaWiki installation and config for Wiki families.
 */

require_once __DIR__ . '/Maintenance.php';

define( 'MW_CONFIG_CALLBACK', 'Installer::overrideConfig' );
define( 'MEDIAWIKI_INSTALL', true );

class FamilyInstaller extends Maintenance {

	function __construct() {
		parent::__construct();
		global $IP;

		$this->addDescription( "CLI-based MediaWiki family installation.\nDefault options are indicated in parentheses." );
		$this->addArg( 'name', 'The name of the wiki (MediaWiki)', false );
		$this->addOption(
			'scriptpath',
			'The relative path of the wiki in the web server (/wiki)',
			false,
			true
		);
		$this->addOption( 'lang', 'The language to use (en)', false, true );

		$this->addOption( 'dbtype', 'The type of database (mysql)', false, true );
		$this->addOption( 'dbserver', 'The database host (localhost)', false, true );
		$this->addOption( 'dbport', 'The database port; only for PostgreSQL (5432)', false, true );
		$this->addOption( 'dbname', 'The database name (my_wiki)', false, true );

		$this->addOption( 'dbpath', 'The path for the SQLite DB ($IP/data)', false, true );
		$this->addOption( 'dbprefix', 'Optional database table name prefix', false, true );
		$this->addOption( 'installdbuser', 'The user to use for installing (root)', false, true );
		$this->addOption( 'installdbpass', 'The password for the DB user to install as.', false, true );
		$this->addOption( 'dbuser', 'The user to use for normal operations (wikiuser)', false, true );
		$this->addOption( 'dbpass', 'The password for the DB user for normal operations', false, true );
		$this->addOption( 'dbpassfile', 'An alternative way to provide dbpass option, as the contents of this file', false, true );
		$this->addOption( 'confpath', "Path to write LocalSettings.php to ($IP)", false, true );
		$this->addOption( 'dbschema', 'The schema for the MediaWiki DB in PostgreSQL/Microsoft SQL Server (mediawiki)', false, true );
		$this->addOption( 'mainpagecontentpath', 'Path to load custom main page content from, instead of the standard message.', false );
		$this->addOption( 'skipinterwiki', 'Don\'t fill the InterWiki table with the default values.', false );
		$this->addOption( 'env-checks', "Run environment checks only, don't change anything" );
	}

	function execute() {
		global $IP;

		$siteName = $this->getArg( 0, 'MediaWiki' ); // Will not be set if used

		$dbpassfile = $this->getOption( 'dbpassfile' );
		if ( $dbpassfile !== null ) {
			if ( $this->getOption( 'dbpass' ) !== null ) {
				$this->error( 'WARNING: You have provided the options "dbpass" and "dbpassfile". ' . 'The content of "dbpassfile" overrides "dbpass".' );
			}
			MediaWiki\suppressWarnings();
			$dbpass = file_get_contents( $dbpassfile ); // returns false on failure
			MediaWiki\restoreWarnings();
			if ( $dbpass === false ) {
				$this->error( "Couldn't open $dbpassfile", true );
			}
			$this->mOptions['dbpass'] = trim( $dbpass, "\r\n" );
		}

		$mainPageContentFile = $this->getOption( 'mainpagecontentpath' );
		if ( $mainPageContentFile !== null ) {
			MediaWiki\suppressWarnings();
			$mainPageContent = file_get_contents( $mainPageContentFile ); // returns false on failure
			MediaWiki\restoreWarnings();
			if ( $mainPageContent === false ) {
				$this->error( "Couldn't open $mainPageContentFile", true );
			}
		} else {
			$mainPageContent = null;
		}

		$options = [
			'mainpagecontent' => $mainPageContent
		];

		$options = array_merge( $this->mOptions, $options );

		$installer = InstallerOverrides::getCliInstaller( $siteName, null, $options );

		$status = $installer->doEnvironmentChecks();
		if ( $status->isGood() ) {
			$installer->showMessage( 'config-env-good' );
		} else {
			$installer->showStatusMessage( $status );

			return;
		}
		if ( !$this->hasOption( 'env-checks' ) ) {
			$installer->execute();
			$installer->writeConfigurationFile( $this->getOption( 'confpath', $IP ) );
		}
	}

	function validateParamsAndArgs() {
		if ( !$this->hasOption( 'env-checks' ) ) {
			parent::validateParamsAndArgs();
		}
	}
}

$maintClass = 'FamilyInstaller';

require_once RUN_MAINTENANCE_IF_MAIN;
