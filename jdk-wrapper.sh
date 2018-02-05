#!/bin/sh

# Copyright 2018 Ville Koskela
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ** DISCLAIMER **
#
# By using this script you agree to the license agreement specified for all
# versions of the JDK you invoke this script for. The author(s) assume no
# responsibility for compliance with this license agreement.

# ** USAGE **
#
# **IMPORTANT**: Sometime in May 2017 Oracle started requiring an Oracle Technology
# Network (OTN) account for downloading anything but the latest JDK version. To work
# around this either:
#
#   1) Manually download and cache the JDKs elsewhere (e.g. Artifactory, Nexus, S3, etc.) and use the `JDKW_SOURCE` to specify the location. For example:
#
#       > JDKW_SOURCE='http://artifactory.example.com/jdk/${JDKW_DIST}/jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}' JDKW_DIST=oracle JDKW_VERSION=8u121 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>
#
#   2) Specify OTN credentials using the `JDKW_USERNAME` and `JDKW_PASSWORD` arguments to specify credentials. For example:
#
#       > JDKW_USERNAME=me@example.com JDKW_PASSWORD=secret JDKW_DIST=oracle JDKW_VERSION=8u121 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>
#
# If the JDK is not found in the local cache then it an attempt will be made to
# download it from OTN regardless of whether a login/password was provided. You
# will likely want developers (or some subset of developers) using the OTN
# login version via the __.jdkw__ file in their home directory (e.g. for testing
# JDK upgrades before making them available) while other developers and headless
# builds (e.g. Jenkins, Travis, Code Build, etc.) use a cached version. As with
# any use of this script **you** are responsible for compliance with the Oracle
# JDK license agreement and the OTN end user license agreement and any other
# agreements to which you are bound.
#
# Simply set your desired JDK and wrap your command relying on the JDK
# with a call to the jdk_wrapper.sh script.
#
# e.g.
# > JDKW_DIST=oracle JDKW_VERSION=8u65 JDKW_BUILD=b13 jdk-wrapper.sh <CMD>
#
# You can also set global values with a .jdkw properties file in your home
# directory or alternatively create a file called .jdkw in the working directory
# with the configuration properties. In either case the format is:
#
# e.g.
# JDKW_DIST=oracle
# JDKW_VERSION=8u65
# JDKW_BUILD=b13
#
# Then wrap your command:
#
# e.g.
# > jdk-wrapper.sh <CMD>
#
# The third option is to pass arguments to jdk-wrapper.sh which define the
# configuration. Any argument that begins with "JDKW_" will be considered a
# configuration parameter, everything from the first non-configuration parameter
# onward is considered part of the command.
#
# e.g.
# > jdk-wrapper.sh JDKW_DIST=oracle JDKW_VERSION=8u65 JDKW_BUILD=b13 <CMD>
#
# Finally, any combination of these four forms of configuration is permissible.
# The order of precedence from highest to lowest is:
#
#   1) Command Line
#   2) .jdkw (working directory)
#   3) ~/.jdkw (home directory)
#   4) Environment
#
# The wrapper script will download, cache and set JAVA_HOME before executing
# the specified command.
#
# Configuration via environment variables or property file:
#
# JDKW_DIST : Distribution type (one of: oracle, zulu). Required.
# JDKW_VERSION : Version identifier (e.g. 8u65). Required.
# JDKW_BUILD : Build identifier (e.g. b17). Required.
# JDKW_TOKEN : Download token (e.g. e9e7ea248e2c4826b92b3f075a80e441). Optional.
# JDKW_JCE : Include Java Cryptographic Extensions (e.g. false). Optional.
# JDKW_RELEASE : Version of JDK Wrapper (e.g. 0.9.0 or latest). Optional.
# JDKW_TARGET : Target directory (e.g. /var/tmp). Optional.
# JDKW_PLATFORM : Platform specifier (e.g. 'linux-x64'). Optional.
# JDKW_EXTENSION : Archive extension (e.g. 'tar.gz'). Optional.
# JDKW_SOURCE : Source url format for download. Optional.
# JDKW_USERNAME: Username for OTN sign-on. Optional.
# JDKW_PASSWORD: Password for OTN sign-on. Optional.
# JDKW_VERBOSE : Log wrapper actions to standard out. Optional.
#
# By default the JDK Wrapper release is latest.
# By default the Java Cryptographic Extensions are included*.
# By default the target directory is ~/.jdk.
# By default the platform is detected using uname.
# By default the extension depends on the platform and distribution:
#     * dmg is used for Darwin (MacOS)
#     * tar.gz is used for Linux/Solaris
# By default the source url is from the distribution type provider.
# By default the wrapper does not log.
#
# * As of JDK version 9 the Java Cryptographic Extensions are bundled with the
# JDK and are not downloaded separately. Therefore, the value of JDKW_JCE is
# ignored for JDK 9. The JDKW_JCE flag only applies if JDKW_DIST is oracle.
#
# IMPORTANT: The JDKW_TOKEN is required for oracle release 8u121-b13 and newer
# except it is not required for oracle release JDK 9.0.1 but is required for
# other JDK 9 releases (as of 2/4/18). JDKW_TOKEN does not apply to zulu.

log_err() {
  l_prefix=$(date  +'%H:%M:%S')
  printf "[%s] %s\n" "${l_prefix}" "$@" 1>&2;
}

log_out() {
  if [ -n "${JDKW_VERBOSE}" ]; then
    l_prefix=$(date  +'%H:%M:%S')
    printf "[%s] %s\n" "${l_prefix}" "$@"
  fi
}

# Default curl options
CURL_OPTIONS=""

# Load properties file in home directory
if [ -f "${HOME}/.jdkw" ]; then
  . "${HOME}/.jdkw"
fi

# Load properties file in working directory
if [ -f ".jdkw" ]; then
  . "./.jdkw"
fi

# Process command line arguments
for ARG in "$@"; do
  JDKW_ARG=$(echo "${ARG}" | grep 'JDKW_.*')
  if [ -n "${JDKW_ARG}" ]; then
    eval ${ARG}
  else
    break
  fi
done

# Set globals (overriding only support for development and testing)
if [ -z "${JDKW_BASE_URI}" ]; then
  JDKW_BASE_URI="https://github.com/koskilabs/jdk-wrapper"
fi
if [ -z "${JDKW_IMPL}" ]; then
  JDKW_IMPL="jdkw-impl.sh"
fi
if [ -z "${JDKW_WRAPPER}" ]; then
  JDKW_WRAPPER="jdk-wrapper.sh"
fi

# Process configuration
if [ -z "${JDKW_RELEASE}" ]; then
  JDKW_RELEASE="latest"
  log_out "Defaulted to version ${JDKW_RELEASE}"
fi
if [ -z "${JDKW_TARGET}" ]; then
  JDKW_TARGET="${HOME}/.jdk"
  log_out "Defaulted to target ${JDKW_TARGET}"
fi
if [ -z "${JDKW_VERBOSE}" ]; then
  CURL_OPTIONS="${CURL_OPTIONS} --silent"
fi

# Resolve latest version
if [ "${JDKW_RELEASE}" = "latest" ]; then
  JDKW_RELEASE=$(curl ${CURL_OPTIONS} -f -k -L 'Accept: application/json' \"${JDKW_BASE_URI}/releases/latest\" | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  log_out "Resolved latest version to ${JDKW_RELEASE}"
fi

# Define source and target
JDKW_RELEASE="${JDKW_BASE_URI}/releases/download/jdk-wrapper-${JDKW_RELEASE}"
JDKW_PATH="${JDKW_TARGET}/jdkw/${JDKW_RELEASE}"

# Ensure target directory exists
if [ ! -d "${JDKW_PATH}" ]; then
  log_out "Creating target directory ${JDKW_PATH}"
  safe_command "mkdir -p \"${JDKW_PATH}\""
fi

# Download the jdk wrapper version
if [ ! -f "${JDKW_PATH}/${JDKW_IMPL}" ]; then
  jdkw_url="${JDKW_RELEASE}/${JDKW_IMPL}"
  log_out "Downloading JDK Wrapper implementation from ${jdkw_url}"
  safe_command "curl ${CURL_OPTIONS} -f -k -L -o \"${JDKW_PATH}/${JDKW_IMPL}\" \"${jdkw_url}\""
fi
if [ ! -f "${JDKW_PATH}/${JDKW_WRAPPER}" ]; then
  jdkw_url="${JDKW_RELEASE}/${JDKW_WRAPPER}"
  log_out "Downloading JDK Wrapper wrapper from ${jdkw_url}"
  safe_command "curl ${CURL_OPTIONS} -f -k -L -o \"${JDKW_PATH}/${JDKW_WRAPPER}\" \"${jdkw_url}\""
fi

# Check whether this wrapper is the one specified for this version
jdkw_download="${JDKW_PATH}/${JDKW_WRAPPER}"
jdkw_current="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/$(basename "$0")"
if [ $(sha1sum "${jdkw_download}") != $(sha1sum "${jdkw_current}") ]; then
  printf "\e[0;31m[WARNING]\e[0m Your jdk-wrapper.sh file does not match your JDKW_RELEASE."
  printf "Update your jdk-wrapper.sh to match by running: "
  printf "cp \"${jdkw_download}\" \"${jdkw_current}\""
fi

# Execute the provided command
${JDKW_PATH}/${JDKW_IMPL} $@
exit $?
