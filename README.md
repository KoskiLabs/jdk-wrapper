jdk-wrapper
===========

__DISCLAIMER__

_By using this script you agree to the license agreement specified for all
versions of the Oracle or Zulu JDK you invoke this script for. The author(s)
assume no responsibility for compliance with the Oracle or Zulu JDK license
agreement or any other applicable agreements. Please see [LICENSE](LICENSE)
for additional conditions of use._

<a href="https://raw.githubusercontent.com/KoskiLabs/jdk-wrapper/master/LICENSE">
    <img src="https://img.shields.io/hexpm/l/plug.svg"
         alt="License: Apache 2">
</a>
<a href="https://travis-ci.org/KoskiLabs/jdk-wrapper/">
    <img src="https://travis-ci.org/KoskiLabs/jdk-wrapper.png"
         alt="Travis Build">
</a>
<a href="https://github.com/KoskiLabs/jdk-wrapper/releases">
    <img src="https://img.shields.io/github/release/KoskiLabs/jdk-wrapper.svg"
         alt="Releases">
</a>
<a href="https://github.com/KoskiLabs/jdk-wrapper/releases">
    <img src="https://img.shields.io/github/downloads/KoskiLabs/jdk-wrapper/total.svg"
         alt="Downloads">
</a>

Provides automatic download, unpacking and usage of specific JDK versions to facilitate repeatable zero-prerequisite builds of Java based software.

Quick Start
-----------

1) Download `jdk-wrapper.sh` from the [latest release](https://github.com/Koskilabs/jdk-wrapper/releases/latest) script into your project in the directory where you execute your build from (typically the project root directory).

2) Make the `jdk-wrapper.sh` executable (e.g. `chmod +x jdk-wrapper.sh`).

3) Create a `.jdkw` file in the same directory as `jdk-wrapper.sh`.

4) Populate the `.jdkw` file with contents from the table below. Customize the file contents by referring to the section _Version and Build_ for information on how to discover and specify a particular JDK version.

5) Execute your build command by wrapping it: `./jdk-wrapper.sh <BUILD COMMAND>`.

6) Periodically update the contents of your `.jdkw` file to reflect new JDK releases or new releases of JDK Wrapper.

Distribution | Version             | `.jdkw`
------------ | ------------------- | -------
oracle       | `6u45`              | [sample](https://raw.githubusercontent.com/KoskiLabs/jdk-wrapper/master/examples/oracle.6u45.jdkw)
oracle       | `7u4` to `8u112`    | [sample](https://raw.githubusercontent.com/KoskiLabs/jdk-wrapper/master/examples/oracle.7u4-8u112.jdkw)
oracle       | `8u121` to `8u162`  | [sample](https://raw.githubusercontent.com/KoskiLabs/jdk-wrapper/master/examples/oracle.8u121-8u162.jdkw)
oracle       | `9.0.1`             | [sample](https://raw.githubusercontent.com/KoskiLabs/jdk-wrapper/master/examples/oracle.9.0.1.jdkw)
oracle       | `9.0.4` to current  | [sample](https://raw.githubusercontent.com/KoskiLabs/jdk-wrapper/master/examples/oracle.9.0.4-current.jdkw)
oracle       | `10.0.1`            | [sample](https://raw.githubusercontent.com/KoskiLabs/jdk-wrapper/master/examples/oracle.10.0.1-current.jdkw)
zulu         | any available       | [sample](https://raw.githubusercontent.com/KoskiLabs/jdk-wrapper/master/examples/zulu.any.jdkw)

Usage
-----

Simply specify the desired JDK version and wrap your command relying on the JDK with a call to the `jdk-wrapper.sh` script.

The first configuration option is to pass arguments to `jdk-wrapper.sh` which define the configuration. Any argument that begins with `JDKW_` will be
considered a configuration parameter, everything starting from the first non-configuration parameter onward is considered part of the command.

    > ./jdk-wrapper.sh JDKW_VERSION=0.9.0 JDKW_DIST=oracle JDKW_VERSION=8u121 JDKW_BUILD=b13 JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441 <CMD>

Alternatively, you can set these parameters as part of the environment. For example:

    > JDKW_DIST=oracle JDKW_VERSION=8u121 JDKW_BUILD=b13 JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441 ./jdk-wrapper.sh <CMD>

Instead of setting the environment variables on the command line you can set them in your session.

    > export JDKW_DIST=oracle
    > export JDKW_VERSION=8u121
    > export JDKW_BUILD=b13
    > export JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441
    > ./jdk-wrapper.sh <CMD>

Alternatively, create a `.jdkw` file in the working directory for per-project configuration (recommended).

```
JDKW_DIST=oracle
JDKW_VERSION=8u131
JDKW_BUILD=b11
JDKW_TOKEN=d54c1d3a095b4ff2b6607d096fa80163
```

You can override the directory by specifying the `JDKW_BASE_DIR` configuration either in the environment or on the command line. Since this
value controls where to find the the `.jdkw` file it is the only configuration value that cannot be loaded from a file. For example:

    > ./jdk-wrapper.sh JDKW_BASE_DIR=/usr/local/etc <CMD>

Lastly, you can also specify configuration values in a `.jdkw` file in your home directory for per-user configuration (e.g. for OTN credentials).

```
JDKW_DIST=oracle
JDKW_VERSION=8u121
JDKW_BUILD=b13
JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441
```

Once you have configured JDK Wrapper execute `jdk-wrapper.sh` script passing in your command and its arguments.

    > ./jdk-wrapper.sh <CMD>

Finally, any combination of these four forms of configuration is permissible. The order of precedence for configuration from highest to lowest is:

1) Command Line
2) Environment
3) .jdkw (working directory)
4) .jdkw (`jdk-wrapper.sh` directory)
5) ~/.jdkw (home directory)

The wrapper script will download and cache the specified JDK version and set `JAVA_HOME` appropriately before executing the specified command.

### Configuration

Regardless of how the configuration is specified it supports the following:

* JDKW_DIST : Distribution type (e.g. oracle, zulu). Required.
* JDKW_VERSION : Version identifier (e.g. '8u65'). Required.
* JDKW_BUILD : Build identifier (e.g. 'b17'). Required.
* JDKW_TOKEN : Download token (e.g. e9e7ea248e2c4826b92b3f075a80e441). Optional.
* JDKW_RELEASE : Version of JDK Wrapper (e.g. 0.9.0 or latest). Optional.
* JDKW_JCE : Include Java Cryptographic Extensions (e.g. false). Optional.
* JDKW_TARGET : Target directory (e.g. '/var/tmp'). Optional.
* JDKW_PLATFORM : Platform specifier (e.g. 'linux-x64'). Optional.
* JDKW_EXTENSION : Archive extension (e.g. 'tar.gz'). Optional.
* JDKW_SOURCE : Source url format for download. Optional.
* JDKW_USERNAME: Username for OTN sign-on. Optional.
* JDKW_PASSWORD: Password for OTN sign-on. Optional.
* JDKW_VERBOSE : Log wrapper actions to standard out. Optional.

The default JDK Wrapper release is `latest`.<br/>
The default target directory is `~/.jdk`.<br/>
The default platform is detected using `uname`.<br/>
By default the Java Cryptographic Extensions are included*.<br/>
By default the extension depends on the distribution and platform type.<br/>
* `dmg` is used for Darwin (MacOS)
* `tar.gz` is used for Linux
* `tar.gz` is used for Solaris
* `exe` is used under Oracle for Windows
* `zip` is used under Zulu for Windows
By default the source url is from the distribution type provider.<br/>
By default the wrapper does not log.

NOTE: As of JDK version 9 the Java Cryptographic Extensions are bundled with the
JDK and are not downloaded separately. Therefore, the value of JDKW_JCE is
ignored for JDK 9. The `JDKW_JCE` flag only applies if `JDKW_DIST` is oracle.

**IMPORTANT**: The `JDKW_TOKEN` is required for oracle release 8u121-b13 and newer
except it is not required for oracle release JDK 9.0.1 but is required for
other JDK 9 releases (as of 2/4/18). `JDKW_TOKEN` does not apply to zulu.

Additionally, there is the `JDKW_BASE_DIR` configuration value which is only loaded
from the environment or command line with the command line value having higher
precedence. This configuration value overrides the path where to locate the
`.jdkw` file which by default is the current working directory. This is useful
in situations where you cannot `cd` into the project directory or if you have
a shared `.jdkw` file for multiple projects.

### Version and Build

#### Oracle

The desired version and build of the Oracle JDK may be determined as follows:

* Browse to the [Java SE Downloads](http://www.oracle.com/technetwork/java/javase/downloads/index.html) page.
* Click the "JDK Download" button on the right.
* Locate the desired version.
* Accept the associated license agreement.
* Hover over one of the download links.

This page only contains the _latest_ versions. Archived versions can be found here:

Archived versions of JDK9 are [listed here](http://www.oracle.com/technetwork/java/javase/downloads/java-archive-javase9-3934878.html).
Archived versions of JDK8 are [listed here](http://www.oracle.com/technetwork/java/javase/downloads/java-archive-javase8-2177648.html).
Archived versions of JDK7 are [listed here](http://www.oracle.com/technetwork/java/javase/downloads/java-archive-downloads-javase7-521261.html).

However, these pages require an OTN account to access and to use this script with. Please see _Oracle Technology Network_ at the end of this
document for details.

All the links for JDK 7 and JDK 8 contain a path element named `{MAJOR}u{MINOR}-{BUILD}`, for example `8u73-b02` where `8u73` would be used
as the value for `JDKW_VERSION` and `b02` the value for `JDKW_BUILD`. For versions `8u121-b13` and higher, the link contains an alpha-numeric
path segment that looks like `e9e7ea248e2c4826b92b3f075a80e441` which needs to be set as the `JDKW_TOKEN`.

However, Oracle changed their conventions again with JDK 9. For versions `9.0.1` and higher, the path element is named the `{X}.{Y}.{Z}+{BUILD}`,
for example `9.0.1+11` where `9.0.1` would be used as the value for `JDKW_VERSION` and `11` the value for `JDKW_BUILD`. Also, `JDKW_TOKEN` was
not needed for `9.0.1` but is required for `9.0.4` and newer.

#### Zulu

The desired version of the build of the Zulu (aka Open) JDK may be determined as follows:

* Browse to one of [Mac Downoads](https://www.azul.com/downloads/zulu/zulu-mac/) or [Linux Downloads](https://www.azul.com/downloads/zulu/zulu-linux/)
* Locate the desired version.
* Hover over one of the download links.

All the links contain a path element named `zulu{X}.{Y}.{Z}.{W}-jdk{A}.{B}.{C}`, for example `zulu8.25.0.3-jdk8.0.153` where `8.0.153` would
be used as the value for `JDKW_VERSION` and `8.25.0.3` the value for `JDKW_BUILD`.

### Caching

The JDK versions specified over all invocations of the JDK Wrapper script are cached in the directory specified by `JDKW_TARGET`
variable in perpetuity. It is recommended that you purge the cache periodically to prevent it from growing unbounded.

### Travis

There are three changes necessary to use the `jdk-wrapper.sh` script in your Travis build. First, ensure that the `JDKW_TARGET` is configured as a cache directory:

```yml
cache:
  directories:
  - $HOME/.jdk
```

Second, if your project does not use `.jdkw` file then configure the `JDKW_VERSION` and `JDKW_BUILD` environment variables to specify the JDK to use:

```yml
env:
  global:
  - JDKW_DIST=oracle
  - JDKW_VERSION=8u121
  - JDKW_BUILD=b13
  - JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441
```

To create a matrix build against multiple versions of the JDK simply specify the environment variables like this:

```yml
env:
  - JDKW_DIST=oracle JDKW_VERSION=7u79 JDKW_BUILD=b15
  - JDKW_DIST=oracle JDKW_VERSION=8u121 JDKW_BUILD=b13 JDKW_TOKEN=e9e7ea248e2c4826b92b3f075a80e441
```

Remember you can omit fields like `JDKW_VERSION` and `JDKW_DIST` if you have a `.jdkw` file which defines them. Finally, invoke your build
command using the JDK Wrapper script. The following assumes you have downloaded and included `jdk-wrapper.sh` in your project.

```yml
script:
- ./jdk-wrapper.sh mvn install
```

Alternatively, you may download the _latest_ (possibly unreleased) version and execute it as follows (however, this is __not__ recommended):

```yml
script:
- curl -s https://raw.githubusercontent.com/koskilabs/jdk-wrapper/master/jdkw-impl.sh | bash /dev/stdin mvn install
```

If your repository contains a `.jdkw` properties file it is __not__ sufficient to set the environment variables to create a matrix build
because the `.jdkw` properties file will override the environment variables. Instead you must set the environment variables and then pass
them as arguments to `jdk-wrapper.sh` because arguments have higher precedence than the `.jdkw` file as follows:

```yml
script:
- ./jdk-wrapper.sh JDKW_DIST=oracle JDKW_VERSION=${JDKW_VERSION} JDKW_BUILD=${JDKW_BUILD} JDKW_TOKEN=${JDKW_TOKEN} mvn install
```

This is most commonly the case when you have a JDK version that you develop against (typically the latest) specified in `.jdkw` but desire a
build which validates against multiple (older) JDK versions.

### Shared Repository

If you are part of an organization, it may be beneficial to download and store the JDK versions your team uses to a shared location and to
distribute from this location to individual team members via JDK Wrapper. Often this reduces latency and bandwidth consumption as well as
ensuring that your team has the desired version of the JDK available even if it is no longer available upstream. You can do this by configuring the
`JDKW_SOURCE` parameter in your `.jdkw` file to define the url pattern for your repository.

One or more persons in your organization would be responsible for downloading new versions of the JDK from the desired vendor(s) and uploading
these to your repository. Once available, others can consume them from your repository. This strategy is particularly useful for archived Oracle
packages which require an OTN account to download (see _Oracle Technology Network_ below). Specifically, it may be less desirable to either
require that all the members of your organization have OTN accounts or to distribute and manage shared OTN credentials. In fact, such strategies
may even be contrary to the OTN or other Oracle terms of service (adherence to which **you** and **your organization** are solely responsible for).

To avoid renaming the artifacts from Oracle and Zulu here are example `JDKW_SOURCE` values for different versions:

Oracle JDK 7 and JDK 8:
```
http://artifactory.example.com/jdk/${JDKW_DIST}/jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}
```

Oracle JDK 9:
```
http://artifactory.example.com/jdk/${JDKW_DIST}/jdk-${JDKW_VERSION}_${JDKW_PLATFORM}_bin.${JDKW_EXTENSION}
```

Zulu:
```
http://artifactory.example.com/jdk/${JDKW_DIST}/zulu${JDKW_BUILD}-jdk${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}
```

### Windows

There are four common ways to execute shell like JDK Wrapper under Windows: Cygwin, Msys2, MinGW and the new Windows Subsystem for Linux (WSL).
When the JDK is installed from an executable (e.g. for Oracle under Cygwin) [User Access Control](https://docs.microsoft.com/en-us/windows/access-protection/user-account-control/how-user-account-control-works)
will prompt you to allow the installation. Please disable User Access Control or select a distribution with a non-executable Windows installation
(e.g. Zulu).

#### Cygwin (Supported)

[Cygwin](https://www.cygwin.com/) is a collection of tools which provide a Linux like environment in Windows by providing a POSIX
compatibility layer between the Cygwin environment and the Windows environment. Under Cygwin JDK Wrapper downloads and installs the Windows
JDK.

#### Msys2 (Supported)

[Msys2](http://www.msys2.org/) is second version of the Minimalist GNU For Windows (MinGW; see below), this version takes a different approach by
providing a POSIX compatibility layer using Cygwin libraries while still providing the MinGW compiler for creating native Windows
applications. Under Msys JDK Wrapper downloads and installs the Windows JDK.

Known Issues:
* There is a known incompatibility with the `/bin/start` script which does not allow more than one argument to be passed. You can find more
details and the current status of this issue in [MSYS2-packages#1177](https://github.com/Alexpux/MSYS2-packages/issues/1177). The easiest
thing to do is patch your local install.

#### WSL (Supported)

The Windows Subsystem for Linux (WSL) is the latest take on Linux in Windows and is provided by Microsoft itself. You can find more
information about WSL including installation instructions on [Microsoft's website](https://docs.microsoft.com/en-us/windows/wsl/install-win10).
In the case of WSL unlike Msys2 or Cygwin, the environment supports execution of actual Linux binaries. This made it more straight forward
and also provided better integration with WSL for JDK Wrapper to install the Linux JDK than the Windows one. Under WSL JDK Wrapper downloads
and installs the Linux JDK.

#### MinGW (Not Supported)

The Minimalist GNU for Windows or [MinGW](http://www.mingw.org/) provides utilities and tools compiled for and running natively on Windows.
MinGW does not provide a POSIX compatible environment. Fortunately, JDK Wrapper does not require a full POSIX environment. After installing
MinGW, you must download and compile from source: curl and its dependencies zlib, pthreads, openssl and libssh2. Although not supported,
under MinGW JDK Wrapper downloads and installs the Windows JDK.

Known Issues:
* Similar to Msys2 there is a known incompatibility with the `/bin/start` script which does not allow more than one argument to be passed.
You can find more details and the current status of this issue in [mingw#1963](https://sourceforge.net/p/mingw/bugs/1963/). The easiest
thing to do is patch your local install.

Prerequisites
-------------

The jdk-wrapper script may work with other versions or with suitable replacements but has been tested with these:

* posix shell: bash (4.4.12), BusyBox (1.25.1)
* awk (4.1.4)
* curl (7.51.0)
* grep (3.0)
* sed (4.4)
* sort (8.27)
* sha256sum (8.29) or shasum (5.84) or sha1sum (8.27)  or md5

Plus tools for extracting files from the target archive type (e.g. tar.gz, dmg, etc.) such as gzip, tar or xar (for example).

Oracle Technology Network
-------------------------

**IMPORTANT**: Sometime in May 2017 Oracle started requiring an Oracle Technology Network (OTN) account for downloading anything but the latest
JDK version. To work around this either:

 1) Manually download and cache the JDKs elsewhere (e.g. Artifactory, Nexus, S3, etc.) and use the `JDKW_SOURCE` to specify the location. For example:

    > JDKW_SOURCE='http://artifactory.example.com/jdk/${JDKW_DIST}/jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}' JDKW_DIST=oracle JDKW_VERSION=8u121 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>

Take care with this option since the Oracle JDK archive naming convention can change between versions (e.g. from 8 to 9).

 2) Specify OTN credentials by using the `JDKW_USERNAME` and `JDKW_PASSWORD` arguments. For example:

    > JDKW_USERNAME=me@example.com JDKW_PASSWORD=secret JDKW_DIST=oracle JDKW_VERSION=8u121 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>

The command above is for illustrative purposes only. You should never write your password out as part of a JDK Wrapper command. Instead store
your OTN credentials in `~/.jdkw`.

 3) Switch from Oracle JDK to Open JDK and never deal with this problem again. For example:

    > JDKW_DIST=zulu JDKW_BUILD=8.25.0.1 JDKW_VERSION=8.0.152 jdk-wrapper.sh <CMD>

If the JDK is not found in the local cache, then an attempt is made to download it from the user specified source if provided. If that attempt fails or is skipped,
the next attempt uses the publicly available endpoint at Oracle (where only the latest version is available). If that attempt fails, the final step uses
the OTN credentials to login and attempt download via the secure OTN endpoint at Oracle if credentials were provided.

You will likely want developers (or some subset of developers) using the OTN login version via the __.jdkw__ file in their home directory (e.g. for testing
JDK upgrades before making them available) while other developers and headless builds (e.g. Jenkins, Travis, Code Build, etc.) use your private cloud/on-prem cached version. As with
any use of this script **you** are responsible for compliance with the Oracle JDK (or any other provider) license agreement(s) and the OTN end user license agreement if applicable
as well as any other agreements to which you are bound.

Releasing
---------

* Determine the next release version `X.Y.Z` using [semantic versioning](https://semver.org/) based on changes since the last release.
* Create a tag to mark the release:
```
$ git tag -a "X.Y.Z" -m "X.Y.Z"
```
* Push the tag to the origin to trigger the release:
```
$ git push origin --tags
```
* Verify the release was created in [Github](https://github.com/KoskiLabs/jdk-wrapper/releases)

License
-------

Published under Apache Software License 2.0, see LICENSE

&copy; Ville Koskela, 2018

