JDK Wrapper Release Notes
=========================

0.13.5 - May 15, 2020
------------------------
* Remove (fix) quoting around checksum generation and correctly support arguments to `shasum`  -- thanks to [speezepearson](https://github.com/speezepearson)

0.13.4 - May 13, 2020
------------------------
* Fixing wrapper and implementation to allow user input to background child process.

0.13.3 - May 13, 2020
------------------------
* Fixed bug introduced during clean-up of `0.13.1` not forwarding signals to child process. 

0.13.2 - May 9, 2020
------------------------
* Fixed bug introduced during clean-up of `0.13.1`. 

0.13.1 - May 8, 2020
------------------------
* Fixed terminating child processes when jdk-wrapper is running as a background task.
* Cleaned up some (but not all) suggestions from `shellcheck`.

0.13.0 - April 27, 2020
------------------------
* Added support for [Adopt OpenJDK](https://adoptopenjdk.net/) -- thanks to [breucode](https://github.com/breucode)

0.12.2 - November 18, 2019
------------------------
* Fixed bug in jdkw-impl.sh where path was not quoted.

0.12.1 - June 7, 2019
------------------------
* Fixed bug in jdkw-impl.sh returning incorrect result code.

0.12.0 - June 3, 2019
------------------------
* Added notice for future *deprecation* of support for Oracle JDKs in JDK Wrapper. No change in behavior.
* Removed unnecessary branch in `jdkw-impl.sh` checking non-existent variable `in_command`. No change in behavior.
* Fixes to Oracle Technology Network (OTN) login process.
* Oracle test cases all pass locally but no longer pass reliably under Travis; removed all automated Oracle tests.
* Expanded Travis automated tests to include Mac and Windows platforms.
* Renamed latest and archive archive naming patterns to primary and alternate. No change in behavior.
* Updated Open JDK Zulu download alternative path pattern to look for community builds denoted by archive pattern `zulu${JDKW_BUILD}-ca-jdk${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}`.
* Added support for Open JDK Zulu JDKs using libMusl when available overridable by JDKW_LIBC.
* Replaced calls to `uname -o` with `uname -s` which is more portable.

0.11.0 - June 4, 2018
------------------------
* Added configuration support for base directory where to locate .jdkw by default in the current working directory
* Tightened argument matching regular expressions to improve correctness and performance

0.10.0 - May 3, 2018
------------------------
* Added official support for Windows under Cygwin, Msys and WSL
* Unofficial support included for Mingw
* Renamed local variables to lower case to distinguish from environment variables
* Relocated wrapper mismatch warning message to after execution of wrapped command
* Support for Oracle JDK 6 and `bin` format -- thanks to [cbamelis](https://github.com/cbamelis)! ([PR #11](https://github.com/KoskiLabs/jdk-wrapper/pull/11))
* Support for Oracle JDK 10 -- thanks to [cbamelis](https://github.com/cbamelis)! ([PR #12](https://github.com/KoskiLabs/jdk-wrapper/pull/12))
* Fixed argument quoting in both jdk-wrapper.sh and jdkw-impl.sh ([addresses #13](https://github.com/KoskiLabs/jdk-wrapper/issues/13))
* Added support for `sha256sum` and defaulted `shasum` to use `-a 256`
* Updated checksum precedence order to: sha256sum, shasum, sha1sum, and last md5
* Set configuration precedence as (highest to lowest): command line, environment, working directory .jdkw, home directory .jdkw

0.9.3 - March 10, 2018
------------------------
* Improved logging when resolution of `latest` version fails ([partially addresses #5](https://github.com/KoskiLabs/jdk-wrapper/issues/5))
* Fixed MacOS incompatibility computing hash in `jdk-wrapper.sh` ([addresses #6](https://github.com/KoskiLabs/jdk-wrapper/issues/6))
* Added support for `shasum` in addition to `sha1sum` and `md5`

0.9.2 - February 4, 2018
------------------------
* Fixed bug in wrapper comparison of sha1sum where it incorrectly included the file name in the comparison

0.9.1 - February 4, 2018
------------------------
* Fixed several bugs in wrapper:
    * Added missing `-H` prefix to content-type header for `curl` invocation
    * Automatically executable permissions to downloaded files
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
