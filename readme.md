# An installer for MediaWiki Wiki families

This is an installer for use with MediaWiki families.

## Usage
To install, launch `setup.sh`. This script requires 2 arguments:
1. The location of the MediaWiki installation. This folder will be created if it does not exist and will be used to place the newly cloned installation in.
2. The release of MediaWiki to clone from git. This can be either `master` or a specific branch such as `REL1_29` or `wmf/1.30.0-wmf.1`.
3. (Optional) The location of the configuration directory. This folder will be created if it does not exist. It defaults to the folder `config` in the installation folder.

In addition, there is also the configuration file `family.conf`. This file specifies the settings to use during the installation.

## Adding a new wiki
To add a new wiki to the family, launch `createwiki.sh`. This script requires 4 arguments:
1. The database name of the new wiki, including its suffix.
2. The name of the new wiki.
3. The language code of the new wiki. It will be added to `langlist` in the configuration folder if it is not yet in there.
4. The location of the configuration directory.
5. (Optional) Any tags applying to the wiki. This list is comma-separated. To add no tags, pass a single comma to this argument.
6. The location of the `template.sql` file. If TEMPLATEWIKIDBNAME is specified in family.conf, this database will be used instead. If it is not set, `template.sql` will be assumed to exist in the folder where `createwiki.sh` resides.

## Other files in this repository
### familyInstaller
A custom MediaWiki installation script that skips some steps in the installation process. The auto creation of an administrator is skipped, and the accompanying script parameters have been removed. One new parameter has been added: `mainpagecontentpath`, which can be set to a file from which the main page content should be loaded, instead of the regular message used by MediaWiki.
### familyCliInstaller
The override used to skip steps in the installation process, the automatic creation of a sysop, and the automatic creation of the interwiki table. It also implements the support for the custom main page.
