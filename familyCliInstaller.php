<?php
/**
 * Override for the default CliInstaller class of MediaWiki.
 * This override also takes the option mainpagecontent to specify a custom main page taken from a
 * file, rather to use a message.
 * It also removes the createsysop and createinterwikitables steps from the installation process,
 * since those are not needed.
 */

$overrides['CliInstaller'] = 'FamilyCliInstaller';

class FamilyCliInstaller extends CliInstaller {

	/**
	 * @var string Custom content of the main page
	 */
	private $mainPageContent;

	/**
	 * Determines if the interwiki table should be filled with default values
	 *
	 * @var boolean
	 */
	private $skipInterwikiTableInsertion;

	/**
	 * FamilyCliInstaller constructor
	 *
	 * @param string $siteName name of the template wiki
	 * @param string $admin ignored
	 * @param array $option configuration options for the wiki
	 */
	public function __construct( $siteName, $admin = null, array $option = [] ) {
		if ( isset( $option['mainpagecontent'] ) ) {
			$this->mainPageContent = $option['mainpagecontent'];
			unset( $option['mainpagecontent'] );
		} else {
			$this->mainPageContent = null;
		}

		if ( isset( $option['skipinterwiki'] ) ) {
			unset( $option['skipinterwiki'] );
			$this->skipInterwikiTableInsertion = true;
		} else {
			$this->skipInterwikiTableInsertion = false;
		}

		parent::__construct( $siteName, $admin, $option );
	}

	/**
	 * Skip the installation steps sysop creating and interwiki table filling, as those
	 * are counter productive to wiki families, these will be done centrally
	 *
	 * @param DatabaseInstaller $installer
	 * @return array
	 */
	protected function getInstallSteps( DatabaseInstaller $installer ) {
		$steps = parent::getInstallSteps( $installer );

		$skipSteps = [ 'sysop' ];
		if ( $this->skipInterwikiTableInsertion ) {
			$skipSteps[] = 'interwiki';
		}

		$newSteps = [];

		foreach ( $steps as $step ) {

			if ( in_array( $step['name'], $skipSteps ) ) {
				continue;
			}

			$newSteps[] = $step;
		}

		return $newSteps;
	}

	/**
	 * Duplicate of its parent, modified to also accept a file with custom content,
	 * to prevent modifying default messages.
	 *
	 * @param DatabaseInstaller $installer
	 * @return Status
	 */
	protected function createMainpage( DatabaseInstaller $installer ) {
		$status = Status::newGood();
		$title = Title::newMainPage();
		if ( $title->exists() ) {
			$status->warning( 'config-install-mainpage-exists' );
			return $status;
		}
		try {
			$page = WikiPage::factory( $title );
			$text = !empty( $this->mainPageContent ) ?
				$this->mainPageContent :
				wfMessage( 'mainpagetext' )->inContentLanguage()->text();

			$content = new WikitextContent(
				$text . "\n\n" .
				wfMessage( 'mainpagedocfooter' )->inContentLanguage()->text()
			);

			$status = $page->doEditContent( $content,
				'',
				EDIT_NEW,
				false,
				User::newFromName( 'MediaWiki default' )
			);
		} catch ( Exception $e ) {
			// using raw, because $wgShowExceptionDetails can not be set yet
			$status->fatal( 'config-install-mainpage-failed', $e->getMessage() );
		}

		return $status;
	}
}
