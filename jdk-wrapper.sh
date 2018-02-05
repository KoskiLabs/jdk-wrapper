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

# For documentation please refer to:
# https://github.com/KoskiLabs/jdk-wrapper/blob/master/README.md

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
  printf "\e[0;32mUpdate your jdk-wrapper.sh to match by running:\e[0m"
  printf "cp \"${jdkw_download}\" \"${jdkw_current}\""
fi

# Execute the provided command
${JDKW_PATH}/${JDKW_IMPL} $@
exit $?
