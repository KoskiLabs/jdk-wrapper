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

rand() {
  awk 'BEGIN {srand();printf "%d\n", (rand() * 10^8);}'
}

safe_command() {
  l_command=$1
  log_out "${l_command}";
  eval $1
  l_result=$?
  if [ "${l_result}" -ne "0" ]; then
    log_err "ERROR: ${l_command} failed with ${l_result}"
    exit 1
  fi
}

generate_manifest_checksum() {
  l_path=$1
  checksum_exec=""
  if command -v md5 > /dev/null; then
    checksum_exec="md5"
  elif command -v sha1sum > /dev/null; then
    checksum_exec="sha1sum"
  elif command -v shasum > /dev/null; then
    checksum_exec="shasum"
  fi
  if [ -z "${checksum_exec}" ]; then
    log_err "ERROR: No supported checksum command found!"
    exit 1
  fi
  l_escaped_path=$(printf '%s' "${l_path}" | sed -e 's@/@\\\/@g')
  echo $(find "${l_path}" -type f \( -iname "*" ! -iname "manifest.checksum" \) -print0 |  xargs -0 ls -l | awk '{print $5, $9}' | sort | sed 's/^\([0-9]*\) '"${l_escaped_path}"'\/\(.*\)$/\1 \2/' | ${checksum_exec})
}

encode() {
  l_value="$1"
  l_encoded_value=$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "${l_value}" "")
  echo "${l_encoded_value##/?}"
}

otn_extract() {
  l_file=$1
  echo $(grep -o '<[^<]*input[^>]*.' "${l_file}" | grep 'type="hidden"' | sed '/.*name="\([^"]*\)"[ ]*value="\([^"]*\)".*/!d;s//\1=\2/' | xargs -I {} curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "{}" "" | sed 's/\/?\([^\/?]*\)/\1\&/g')
}

otn_signon() {
  l_username=$(encode "userid=$1")
  l_password=$(encode "pass=$2")

  l_cookiejar="${TMPDIR:-/tmp}/otn.cookiejar-$$.$(rand)"
  l_redirectform="${TMPDIR:-/tmp}/otn.redirectform-$$.$(rand)"
  l_signon="${TMPDIR:-/tmp}/otn.signon-$$.$(rand)"
  l_credsubmit="${TMPDIR:-/tmp}/otn.credsubmit-$$.$(rand)"

  if [ -f "${l_cookiejar}" ]; then
    rm -f "${l_cookiejar}"
  fi

  # Download the homepage
  log_out "OTN Login: Getting homepage..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -o /dev/null https://www.oracle.com

  # Download and parse the redirect
  log_out "OTN Login: Getting redirect..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -o "${l_redirectform}" http://www.oracle.com/webapps/redirect/signon?nexturl=https://www.oracle.com/index.html?
  redirect_data=$(otn_extract "${l_redirectform}")

  # Redirect to the sign-on form
  log_out "OTN Login: Getting sign-on..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -o "${l_signon}" -d "${redirect_data}" https://login.oracle.com:443/oaam_server/oamLoginPage.jsp
  signon_data=$(otn_extract "${l_signon}")
  signon_data="${signon_data}${l_username}&"
  signon_data="${signon_data}&${l_password}&"

  # Post the sign-on form
  log_out "OTN Login: Posting login..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -X POST -d "${signon_data}" --referer https://login.oracle.com:443/oaam_server/oamLoginPage.jsp -o /dev/null https://login.oracle.com:443/oaam_server/loginAuth.do

  # Add the accept cookie to the jar
  printf ".oracle.com\tTRUE\t/\tFALSE\t0\toraclelicense\taccept-securebackup-cookie\n" >> "${l_cookiejar}"

  # Complete the sign-on
  log_out "OTN Login: Completing login..."
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -X POST -d "${signon_data}" --referer https://login.oracle.com:443/oaam_server/loginAuth.do -o "${l_credsubmit}" https://login.oracle.com:443/oaam_server/authJump.do?jump=false
  credsubmit_data=$(otn_extract "${l_credsubmit}")

  sleep 3
  
  curl ${CURL_OPTIONS} -H "User-Agent:${OTN_USER_AGENT}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -X POST -d "${credsubmit_data}" --referer https://login.oracle.com:443/oaam_server/authJump.do -o /dev/null https://login.oracle.com:443/oam/server/dap/cred_submit

  # Return the filled cookie jar
  rm "${l_redirectform}"
  rm "${l_signon}"
  OTN_COOKIE_JAR="${l_cookiejar}"
}

extract_oracle() {
  if [ "${JDKW_EXTENSION}" = "tar.gz" ]; then
    safe_command "tar -xzf \"${jdk_archive}\""
    safe_command "rm -f \"${jdk_archive}\""
    package=$(ls | grep "jdk.*" | head -n 1)
    JAVA_HOME="${JDKW_TARGET}/${jdkid}/${package}"
  elif [ "${JDKW_EXTENSION}" = "bin" ]; then
    safe_command "chmod a+x \"${jdk_archive}\""
    safe_command "./\"${jdk_archive}\""
    safe_command "rm -f \"${jdk_archive}\""
    package=$(ls | grep "jdk.*" | head -n 1)
    JAVA_HOME="${JDKW_TARGET}/${jdkid}/${package}"
  elif [ "${JDKW_EXTENSION}" = "dmg" ]; then
    result=$(hdiutil attach "${jdk_archive}" | grep "/Volumes/.*")
    volume=$(echo "${result}" | grep -o "/Volumes/.*")
    mount=$(echo "${result}" | grep -o "/dev/[^ ]*" | tail -n 1)
    package=$(ls "${volume}" | grep "JDK.*\.pkg" | head -n 1)
    safe_command "xar -xf \"${volume}/${package}\" . &> /dev/null"
    safe_command "hdiutil detach \"${mount}\" &> /dev/null"
    jdk=$(ls | grep "jdk.*\.pkg" | head -n 1)
    safe_command "cpio -i < \"./${jdk}/Payload\" &> /dev/null"
    safe_command "rm -f \"${jdk_archive}\""
    safe_command "rm -rf \"${jdk}\""
    safe_command "rm -rf \"javaappletplugin.pkg\""
    JAVA_HOME="${JDKW_TARGET}/${jdkid}/Contents/Home"
  elif [ "${JDKW_EXTENSION}" = "exe" ]; then
    safe_command "chmod +x \"${jdk_archive}\""
    os=$(uname -o)
    if [ "${os}" = "Cygwin" ]; then
      windows_target=$(cygpath -w \"${JDKW_TARGET}/${jdkid}\")
      safe_command "cygstart -wait -o \"./${jdk_archive}\" /s ADDLOCAL=\"ToolsFeature,SourceFeature\" INSTALLDIR=\"${windows_target}\""
    elif [ "${os}" = "Msys" ]; then
      # Requires patch to address bug in Msys /bin/start
      # See: https://github.com/Alexpux/MSYS2-packages/issues/1177
      # See: https://sourceforge.net/p/mingw/bugs/1963/
      windows_target=$(cygpath -w \"${JDKW_TARGET}/${jdkid}\")
      safe_command "start /wait \"./${jdk_archive}\" //s ADDLOCAL=\"ToolsFeature,SourceFeature\" INSTALLDIR=\"${windows_target}\""
    else
      windows_target="${JDKW_TARGET}/${jdkid}"
      safe_command "start /wait \"./${jdk_archive}\" /s ADDLOCAL=\"ToolsFeature,SourceFeature\" INSTALLDIR=\"${windows_target}\""
    fi
    if [ ! -d "${JDKW_TARGET}/${jdkid}/bin" ]; then
      log_err "Installation failed"
      exit 1
    fi
    safe_command "rm -f \"${jdk_archive}\""
    JAVA_HOME="${JDKW_TARGET}/${jdkid}"
  else
    log_err "Unsupported oracle extension ${JDKW_EXTENSION}"
    safe_command "cd ${LAST_DIR}"
    exit 1
  fi
}

extract_zulu() {
  if [ "${JDKW_EXTENSION}" = "tar.gz" ]; then
    safe_command "tar -xzf \"${jdk_archive}\""
    safe_command "rm -f \"${jdk_archive}\""
    package=$(ls | grep "zulu.*" | head -n 1)
    JAVA_HOME="${JDKW_TARGET}/${jdkid}/${package}"
  elif [ "${JDKW_EXTENSION}" = "dmg" ]; then
    result=$(hdiutil attach "${jdk_archive}" | grep "/Volumes/.*")
    volume=$(echo "${result}" | grep -o "/Volumes/.*")
    mount=$(echo "${result}" | grep -o "/dev/[^ ]*" | tail -n 1)
    package=$(ls "${volume}" | grep ".*Zulu.*\.pkg" | head -n 1)
    safe_command "xar -xf \"${volume}/${package}\" . &> /dev/null"
    safe_command "hdiutil detach \"${mount}\" &> /dev/null"
    jdk=$(ls | grep "zulu-.*\.pkg" | head -n 1)
    safe_command "cpio -i < \"./${jdk}/Payload\" &> /dev/null"
    safe_command "rm -f \"${jdk_archive}\""
    safe_command "rm -rf \"${jdk}\""
    JAVA_HOME="${JDKW_TARGET}/${jdkid}/Contents/Home"
  elif [ "${JDKW_EXTENSION}" = "zip" ]; then
    safe_command "unzip \"${jdk_archive}\""
    jdk_dir=$(find . -maxdepth 1 -type d -name 'zulu*' -printf '%P')
    safe_command "rm -f \"${jdk_archive}\""
    JAVA_HOME="${JDKW_TARGET}/${jdkid}/${jdk_dir}"
  else
    log_err "Unsupported zulu extension ${JDKW_EXTENSION}"
    safe_command "cd ${LAST_DIR}"
    exit 1
  fi
}

# Default curl options
CURL_OPTIONS=""

# Default user agent
OTN_USER_AGENT='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36'

# Load properties file in home directory
if [ -f "${HOME}/.jdkw" ]; then
  . "${HOME}/.jdkw"
fi

# Load properties file in working directory
if [ -f ".jdkw" ]; then
  . "./.jdkw"
fi

# Process command line arguments
IN_COMMAND=
COMMAND=
for ARG in "$@"; do
  if [ ! -z ${IN_COMMAND} ]; then
    COMMAND="${COMMAND} \"${ARG}\""
  else
    JDKW_ARG=$(echo "${ARG}" | grep 'JDKW_.*')
    if [ -n "${JDKW_ARG}" ]; then
      eval ${ARG}
    else
      IN_COMMAND=1
      COMMAND="\"${ARG}\""
    fi
  fi
done

# Process configuration
DIST_ORACLE="oracle"
DIST_ZULU="zulu"
PLATFORM_MACOSX=""
PLATFORM_LINUX=""
PLATFORM_SOLARIS=""
PLATFORM_WINDOWS=""
if [ -z "${JDKW_VERSION}" ]; then
  log_err "Required JDKW_VERSION (e.g. 8u65) value not provided or set"
  exit 1
fi
JAVA_MAJOR_VERSION=$(echo "${JDKW_VERSION}" | sed 's/\([0-9]*\).*/\1/')
if [ -z "${JDKW_BUILD}" ]; then
  log_err "Required JDKW_BUILD (e.g. b17) value not provided or set"
  exit 1
fi
if [ "${JDKW_DIST}" = "${DIST_ORACLE}" ]; then
  architecture=$(uname -m)
  if [ "${JAVA_MAJOR_VERSION}" = "9" ]; then
    PLATFORM_MACOSX="osx-x64"
  else
    PLATFORM_MACOSX="macosx-x64"
  fi
  if [ "${architecture}" = "x86_64" ]; then
    PLATFORM_LINUX="linux-x64"
  else
    PLATFORM_LINUX="linux-i586"
  fi
  if [ "${architecture}" = "sparc64" ]; then
    PLATFORM_SOLARIS="solaris-sparcv9"
  elif [ "${architecture}" = "sun4u" ]; then
    PLATFORM_SOLARIS="solaris-sparcv9"
  else
    PLATFORM_SOLARIS="solaris-x64"
  fi
  if [ "${architecture}" = "x86_64" ]; then
    PLATFORM_WINDOWS="windows-x64"
  else
    PLATFORM_WINDOWS="windows-i586"
  fi
elif [ "${JDKW_DIST}" = "${DIST_ZULU}" ]; then
  architecture=$(uname -m)
  PLATFORM_MACOSX="macosx_x64"
  if [ "${architecture}" = "x86_64" ]; then
    PLATFORM_LINUX="linux_x64"
  else
    PLATFORM_LINUX="linux_i686"
  fi
  if [ "${architecture}" = "x86_64" ]; then
    PLATFORM_WINDOWS="win_x64"
  else
    PLATFORM_WINDOWS="win_i686"
  fi
else
  log_err "Unsupported distribution ${JDKW_DIST}"
  exit 1
fi
if [ -z "${JDKW_PLATFORM}" ]; then
  kernel=$(uname)
  os=$(uname -o)
  if [ "${kernel}" = "Darwin" ]; then
    JDKW_PLATFORM="${PLATFORM_MACOSX}"
  elif [ "${kernel}" = "Linux" ]; then
    JDKW_PLATFORM="${PLATFORM_LINUX}"
  elif [ "${kernel}" = "SunOS" ]; then
    JDKW_PLATFORM="${PLATFORM_SOLARIS}"
  elif [ "${os}" = "Cygwin" ]; then
    JDKW_PLATFORM="${PLATFORM_WINDOWS}"
  elif [ "${os}" = "Msys" ]; then
    JDKW_PLATFORM="${PLATFORM_WINDOWS}"
  fi
  if [ -z "${JDKW_PLATFORM}" ]; then
    log_err "JDKW_PLATFORM value not provided or set and unable to determine a reasonable default or not supported by ${JDKW_DIST}"
    exit 1
  fi
  log_out "Detected platform ${JDKW_PLATFORM}"
fi
if [ "${JDKW_DIST}" = "${DIST_ORACLE}" ]; then
  if [ "${JAVA_MAJOR_VERSION}" = "6" ] || [ "${JAVA_MAJOR_VERSION}" = "9" ] ; then
    JDKW_JCE=
    log_out "Forced to no jce"
  elif [ -z "${JDKW_JCE}" ]; then
    JDKW_JCE="true"
    log_out "Defaulted to jce ${JDKW_JCE}"
  fi
else
  JDKW_JCE=
  log_out "Forced to no jce"
fi
if [ -z "${JDKW_TARGET}" ]; then
  JDKW_TARGET="${HOME}/.jdk"
  log_out "Defaulted to target ${JDKW_TARGET}"
fi
default_extension="tar.gz"
if [ "${JDKW_PLATFORM}" = "${PLATFORM_MACOSX}" ]; then
  default_extension="dmg"
fi
if [ "${JDKW_DIST}" = "${DIST_ORACLE}" ]; then
  if [ "${JDKW_PLATFORM}" = "${PLATFORM_WINDOWS}" ]; then
    default_extension="exe"
  fi
elif [ "${JDKW_DIST}" = "${DIST_ZULU}" ]; then
  if [ "${JDKW_PLATFORM}" = "${PLATFORM_WINDOWS}" ]; then
    default_extension="zip"
  fi
fi
if [ -z "${JDKW_EXTENSION}" ]; then
  JDKW_EXTENSION=${default_extension}
  log_out "Defaulted to extension ${JDKW_EXTENSION}"
fi
if [ -z "${JDKW_VERBOSE}" ]; then
  CURL_OPTIONS="${CURL_OPTIONS} --silent"
fi

# Default JDK locations
if [ "${JDKW_DIST}" = "${DIST_ORACLE}" ]; then
  if [ "${JAVA_MAJOR_VERSION}" = "9" ]; then
    LATEST_JDKW_SOURCE='http://download.oracle.com/otn-pub/java/jdk/${JDKW_VERSION}+${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}_${JDKW_PLATFORM}_bin.${JDKW_EXTENSION}'
    ARCHIVED_JDKW_SOURCE='http://download.oracle.com/otn/java/jdk/${JDKW_VERSION}+${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}_${JDKW_PLATFORM}_bin.${JDKW_EXTENSION}'
  else
    LATEST_JDKW_SOURCE='http://download.oracle.com/otn-pub/java/jdk/${JDKW_VERSION}-${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}'
    ARCHIVED_JDKW_SOURCE='http://download.oracle.com/otn/java/jdk/${JDKW_VERSION}-${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}'
  fi
else
  LATEST_JDKW_SOURCE='http://cdn.azul.com/zulu/bin/zulu${JDKW_BUILD}-jdk${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}'
  ARCHIVED_JDKW_SOURCE=''
fi

# Ensure target directory exists
if [ ! -d "${JDKW_TARGET}" ]; then
  log_out "Creating target directory ${JDKW_TARGET}"
  safe_command "mkdir -p \"${JDKW_TARGET}\""
fi

# Build jdk identifier
jdkid="${JDKW_DIST}_${JDKW_VERSION}_${JDKW_BUILD}_${JDKW_PLATFORM}"
if [ "${JDKW_JCE}" = "true" ]; then
  jdkid="${jdkid}_jce"
fi

# Check the JDK contents have not changed
manifest="${JDKW_TARGET}/${jdkid}/manifest.checksum"
if [ -f "${JDKW_TARGET}/${jdkid}/environment" ]; then
  if [ -f "${manifest}" ]; then
    log_out "Verifying manifest integrity..."
    manifest_current="${TMPDIR:-/tmp}/${jdkid}-$$.$(rand)"
    generate_manifest_checksum "${JDKW_TARGET}/${jdkid}" > "${manifest_current}"
    manifest_checksum=$(cat "${manifest}")
    manifest_current_checksum=$(cat "${manifest_current}")
    log_out "Previous: ${manifest_checksum}"
    log_out "Current: ${manifest_current_checksum}"
    safe_command "rm -f \"${manifest_current}\""
    if [ "${manifest_checksum}" != "${manifest_current_checksum}" ]; then
      log_out "Manifest checksum changed; preparing to reinstall"
      safe_command "rm -f \"${JDKW_TARGET}/${jdkid}/environment\""
    else
      log_out "Manifest integrity verified."
    fi
  else
    log_out "Manifest checksum not found; preparing to reinstall"
    safe_command "rm -f \"${JDKW_TARGET}/${jdkid}/environment\""
  fi
fi

# Download and install desired jdk version
if [ ! -f "${JDKW_TARGET}/${jdkid}/environment" ]; then
  log_out "Desired JDK version ${jdkid} not found"
  if [ -d "${JDKW_TARGET}/${jdkid}" ]; then
    safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
  fi

  # Create target directory
  LAST_DIR=$(pwd)
  safe_command "mkdir -p \"${JDKW_TARGET}/${jdkid}\""
  safe_command "cd \"${JDKW_TARGET}/${jdkid}\""

  # JDK
  token_segment=""
  if [ -n "${JDKW_TOKEN}" ]; then
    token_segment="${JDKW_TOKEN}/"
  fi
  jdk_archive="jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}"

  # Download archive
  download_result=-1
  if command -v curl > /dev/null; then
    # Do NOT execute with safe_command; undo operations below on failure

    # 1) Attempt download from user specified source
    if [ -n "${JDKW_SOURCE}" ]; then
      eval "jdk_url=\"${JDKW_SOURCE}\""
      log_out "Attempting download of JDK from ${jdk_url}"
      curl ${CURL_OPTIONS} -f -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o "${jdk_archive}" "${jdk_url}"
      download_result=$?
    fi

    # 2) Attempt download from latest source
    if [ ${download_result} != 0 ]; then
      eval "jdk_url=\"${LATEST_JDKW_SOURCE}\""
      log_out "Attempting download of JDK from ${jdk_url}"
      curl ${CURL_OPTIONS} -f -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o "${jdk_archive}" "${jdk_url}"
      download_result=$?
    fi

    # 3) Attempt download from archive source (only applies to oracle)
    if [ "${JDKW_DIST}" = "${DIST_ORACLE}" ]; then
      if [ ${download_result} != 0 ]; then
        eval "jdk_url=\"${ARCHIVED_JDKW_SOURCE}\""
        log_out "Attempting download of JDK from ${jdk_url}"
        if [ -z "${JDKW_USERNAME}" ]; then
          log_err "No username specified; aborting..."
        elif [ -z "${JDKW_PASSWORD}" ]; then
          log_err "No password specified; aborting..."
        else
          otn_signon "${JDKW_USERNAME}" "${JDKW_PASSWORD}"
          log_out "Initiating authenticated download..."
          curl ${CURL_OPTIONS} -f -k -L -H "User-Agent:${OTN_USER_AGENT}" -b "${OTN_COOKIE_JAR}" -o "${jdk_archive}" "${jdk_url}"
          download_result=$?
        fi
      fi
    fi
  else
    log_err "Could not find curl; aborting..."
    download_result=-1
  fi
  if [ ${download_result} != 0 ]; then
    log_err "Download failed!"
    safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
    exit 1
  fi

  # Extract based on extension
  log_out "Unpacking ${JDKW_EXTENSION}..."
  eval "extract_${JDKW_DIST}"
  printf "export JAVA_HOME=\"%s\"\n" "${JAVA_HOME}" > "${JDKW_TARGET}/${jdkid}/environment"
  printf "export PATH=\"\$JAVA_HOME/bin:\$PATH\"\n" >> "${JDKW_TARGET}/${jdkid}/environment"

  # Download and install matching JCE version
  if [ "${JDKW_JCE}" = "true" ]; then
    # JCE
    # IMPORTANT: There are two differences between jce for oracle jdk 7 and 8
    # 1) The archive name is different.
    # 2) The archive layout is different.

    if [ "${JAVA_MAJOR_VERSION}" = "8" ]; then
      jce_archive="jce_policy-${JAVA_MAJOR_VERSION}.zip"
    elif [ "${JAVA_MAJOR_VERSION}" = "7" ]; then
      jce_archive="UnlimitedJCEPolicyJDK${JAVA_MAJOR_VERSION}.zip"
    else
      log_err "JCE not supported for ${JDKW_DIST} major version ${JAVA_MAJOR_VERSION}"
      safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
      exit 1
    fi
    jce_url="http://download.oracle.com/otn-pub/java/jce/${JAVA_MAJOR_VERSION}/${jce_archive}"

    # Download archive
    log_out "Downloading JCE from ${jce_url}"
    download_result=
    if command -v curl > /dev/null; then
      # Do NOT execute with safe_command; undo operations below on failure
      curl ${CURL_OPTIONS} -j -k -L -H "Cookie: gpw_e24=xxx; oraclelicense=accept-securebackup-cookie;" -o "${jce_archive}" "${jce_url}"
      download_result=$?
    else
      log_err "Could not find curl; aborting..."
      download_result=-1
    fi
    if [ ${download_result} -ne 0 ]; then
      log_err "Download failed of ${jce_url}"
      safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
      exit 1
    fi

    # Extract contents
    safe_command "unzip -qq \"${jce_archive}\""
    if [ "${JAVA_MAJOR_VERSION}" = "8" ]; then
      safe_command "find \"./UnlimitedJCEPolicyJDK${JAVA_MAJOR_VERSION}\" -type f -exec cp {} \"${JAVA_HOME}/jre/lib/security\" \\;"
      safe_command "rm -rf \"./UnlimitedJCEPolicyJDK${JAVA_MAJOR_VERSION}\""
    elif [ "${JAVA_MAJOR_VERSION}" = "7" ]; then
      safe_command "find \"./UnlimitedJCEPolicy\" -type f -exec cp {} \"${JAVA_HOME}/jre/lib/security\" \\;"
      safe_command "rm -rf \"./UnlimitedJCEPolicy\""
    else
      log_err "JCE not supported for ${JDKW_DIST} major version ${JAVA_MAJOR_VERSION}"
      safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
      exit 1
    fi
    safe_command "rm \"${jce_archive}\""
  fi

  # Installation complete
  generate_manifest_checksum "${JDKW_TARGET}/${jdkid}" > "${manifest}"
  safe_command "cd ${LAST_DIR}"
fi

# Setup the environment
log_out "Environment:"
if [ -n "${JDKW_VERBOSE}" ]; then
  cat "${JDKW_TARGET}/${jdkid}/environment"
fi
. "${JDKW_TARGET}/${jdkid}/environment"

# Execute the provided command
log_out "Executing: ${COMMAND}"
eval ${COMMAND}
exit $?
