JDK Wrapper Release Notes
=========================

0.9.2 - February 4, 2018
------------------------
* Fixed bug in wrapper comparison of sha1sum where it incorrectly included the file name in the comparison

0.9.1 - February 4, 2018
------------------------
* Fixed several bugs in wrapper:
    * Added missing `-H` prefix to content-type header for `curl` invocation
    * Automatically executable permissions to downloaded files\
    * Renamed `JDKW_RELEASE` to `JDKW_URI`
    * Missing definition of `safe_command`
* Minor improvements to wrapper code quality:
    * Extracted common `download` function
    * Removed overriding of constants (didn't prove useful)
    * Extracted variables from `printf` statements

0.9.0 - February 4, 2018
------------------------
* Initial port from [github.com/vjkoskela/jdk-wrapper](https://github.com/vjkoskela/jdk-wrapper).
* This is not a backwards compatible port; see [MIGRATION.md](https://github.com/koskilabs/jdk-wrapper/blob/master/MIGRATION.md).
* New required configuration value `JDKW_VERSION` controls the JDK Wrapper script version to use.
* New required configuration value `JDKW_DIST` controlling the distribution; must be either `oracle` or `zulu`.
* Cache directory structure now contains `JDKW_DIST` prefix (all existing caches are invalid!).
* Added support for downloading, unpacking `dmg` and `tar.gz` and installing Zulu (aka OpenJDK) packages.

Published under Apache Software License 2.0, see LICENSE

&copy; Ville Koskela, 2018
