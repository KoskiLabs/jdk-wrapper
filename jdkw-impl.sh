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
  if command -v sha256sum > /dev/null; then
      checksum_exec="sha256sum"
  elif command -v shasum > /dev/null; then
    checksum_exec="shasum -a 256"
  elif command -v sha1sum > /dev/null; then
    checksum_exec="sha1sum"
  elif command -v md5 > /dev/null; then
    checksum_exec="md5"
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
  curl ${curl_options} -H "User-Agent:${otn_user_agent}" -k -L -c "${l_cookiejar}" -o /dev/null https://www.oracle.com

  # Download and parse the redirect
  log_out "OTN Login: Getting redirect..."
  curl ${curl_options} -H "User-Agent:${otn_user_agent}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -o "${l_redirectform}" http://www.oracle.com/webapps/redirect/signon?nexturl=https://www.oracle.com/index.html?
  redirect_data=$(otn_extract "${l_redirectform}")

  # Redirect to the sign-on form
  log_out "OTN Login: Getting sign-on..."
  curl ${curl_options} -H "User-Agent:${otn_user_agent}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -o "${l_signon}" -d "${redirect_data}" https://login.oracle.com:443/oaam_server/oamLoginPage.jsp
  signon_data=$(otn_extract "${l_signon}")
  signon_data="${signon_data}${l_username}&"
  signon_data="${signon_data}&${l_password}&"

  # Post the sign-on form
  log_out "OTN Login: Posting login..."
  curl ${curl_options} -H "User-Agent:${otn_user_agent}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -X POST -d "${signon_data}" --referer https://login.oracle.com:443/oaam_server/oamLoginPage.jsp -o /dev/null https://login.oracle.com:443/oaam_server/loginAuth.do

  # Add the accept cookie to the jar
  printf ".oracle.com\tTRUE\t/\tFALSE\t0\toraclelicense\taccept-securebackup-cookie\n" >> "${l_cookiejar}"

  # Complete the sign-on
  log_out "OTN Login: Completing login..."
  curl ${curl_options} -H "User-Agent:${otn_user_agent}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -X POST -d "${signon_data}" --referer https://login.oracle.com:443/oaam_server/loginAuth.do -o "${l_credsubmit}" https://login.oracle.com:443/oaam_server/authJump.do?jump=false
  credsubmit_data=$(otn_extract "${l_credsubmit}")

  sleep 3
  
  curl ${curl_options} -H "User-Agent:${otn_user_agent}" -k -L -c "${l_cookiejar}" -b "${l_cookiejar}" -X POST -d "${credsubmit_data}" --referer https://login.oracle.com:443/oaam_server/authJump.do -o /dev/null https://login.oracle.com:443/oam/server/dap/cred_submit

  # Return the filled cookie jar
  rm "${l_redirectform}"
  rm "${l_signon}"
  otn_cookie_jar="${l_cookiejar}"
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
    exit 1
  fi
}

# Default curl options
curl_options=""

# Default user agent
otn_user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/57.0.2987.133 Safari/537.36'

# Process (but do not load) properties from environment
env_configuration=
l_fifo="${TMPDIR:-/tmp}/$$.$(rand)"
safe_command "mkfifo \"${l_fifo}\""
env > "${l_fifo}" &
while IFS='=' read -r name value
do
  jdkw_arg=$(echo "${name}" | grep '^JDKW_.*')
  jdkw_base_dir_arg=$(echo "${name}" | grep '^JDKW_BASE_DIR')
  if [ -n "${jdkw_base_dir_arg}" ]; then
    eval "${name}=\"${value}\""
  fi
  if [ -n "${jdkw_arg}" ]; then
    env_configuration="${env_configuration}${name}=\"${value}\" "
  fi
done < "${l_fifo}"
safe_command "rm \"${l_fifo}\""

# Process (but do not load) properties from command line arguments
in_command=
command=
cmd_configuration=
for arg in "$@"; do
  if [ -z ${in_command} ]; then
    jdkw_arg=$(echo "${arg}" | grep '^JDKW_.*')
    jdkw_base_dir_arg=$(echo "${arg}" | grep '^JDKW_BASE_DIR.*')
    if [ -n "${jdkw_base_dir_arg}" ]; then
      eval ${arg}
    fi
    if [ -n "${jdkw_arg}" ]; then
      cmd_configuration="${cmd_configuration}${arg} "
    else
      in_command=1
    fi
  fi
  if [ ! -z ${in_command} ]; then
    case "${arg}" in
      *\'*)
         arg=`printf "%s" "$arg" | sed "s/'/'\"'\"'/g"`
         ;;
      *) : ;;
    esac
    command="${command} '${arg}'"
  fi
done

# Default base directory to current working directory
if [ -z "${JDKW_BASE_DIR}" ]; then
    JDKW_BASE_DIR="."
fi

# Load properties file in home directory
if [ -f "${HOME}/.jdkw" ]; then
  . "${HOME}/.jdkw"
fi

# Load properties file in base directory
if [ -f "${JDKW_BASE_DIR}/.jdkw" ]; then
  . "${JDKW_BASE_DIR}/.jdkw"
fi

# Load properties from environment
eval "${env_configuration}"

# Load properties from command line arguments
eval "${cmd_configuration}"

# Process configuration
dist_oracle="oracle"
dist_zulu="zulu"
platform_macosx=""
platform_linux=""
platform_solaris=""
platform_windows=""
if [ -z "${JDKW_VERSION}" ]; then
  log_err "Required JDKW_VERSION (e.g. 8u65) value not provided or set"
  exit 1
fi
java_major_version=$(echo "${JDKW_VERSION}" | sed 's/\([0-9]*\).*/\1/')
if [ -z "${JDKW_BUILD}" ]; then
  log_err "Required JDKW_BUILD (e.g. b17) value not provided or set"
  exit 1
fi
if [ "${JDKW_DIST}" = "${dist_oracle}" ]; then
  architecture=$(uname -m)
  if [ "${java_major_version}" = "9" ] || [ "${java_major_version}" = "10" ]; then
    platform_macosx="osx-x64"
  else
    platform_macosx="macosx-x64"
  fi
  if [ "${architecture}" = "x86_64" ]; then
    platform_linux="linux-x64"
  else
    platform_linux="linux-i586"
  fi
  if [ "${architecture}" = "sparc64" ]; then
    platform_solaris="solaris-sparcv9"
  elif [ "${architecture}" = "sun4u" ]; then
    platform_solaris="solaris-sparcv9"
  else
    platform_solaris="solaris-x64"
  fi
  if [ "${architecture}" = "x86_64" ]; then
    platform_windows="windows-x64"
  else
    platform_windows="windows-i586"
  fi
elif [ "${JDKW_DIST}" = "${dist_zulu}" ]; then
  architecture=$(uname -m)
  platform_macosx="macosx_x64"
  libc=""
  if [ -d "/etc/apk" ]; then
    libc="_musl"
  fi
  if [ "${architecture}" = "x86_64" ]; then
    platform_linux="linux${libc}_x64"
  else
    platform_linux="linux${libc}_i686"
  fi
  if [ "${architecture}" = "x86_64" ]; then
    platform_windows="win_x64"
  else
    platform_windows="win_i686"
  fi
else
  log_err "Unsupported distribution ${JDKW_DIST}"
  exit 1
fi
if [ -z "${JDKW_PLATFORM}" ]; then
  kernel=$(uname)
  os=$(uname -o)
  if [ "${kernel}" = "Darwin" ]; then
    JDKW_PLATFORM="${platform_macosx}"
  elif [ "${kernel}" = "Linux" ]; then
    JDKW_PLATFORM="${platform_linux}"
  elif [ "${kernel}" = "SunOS" ]; then
    JDKW_PLATFORM="${platform_solaris}"
  elif [ "${os}" = "Cygwin" ]; then
    JDKW_PLATFORM="${platform_windows}"
  elif [ "${os}" = "Msys" ]; then
    JDKW_PLATFORM="${platform_windows}"
  fi
  if [ -z "${JDKW_PLATFORM}" ]; then
    log_err "JDKW_PLATFORM value not provided or set and unable to determine a reasonable default or not supported by ${JDKW_DIST}"
    exit 1
  fi
  log_out "Detected platform ${JDKW_PLATFORM}"
fi
if [ "${JDKW_DIST}" = "${DIST_ORACLE}" ]; then
  if [ "${java_major_version}" = "6" ] || [ "${java_major_version}" = "9" ] || [ "${java_major_version}" = "10" ]; then
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
if [ "${JDKW_PLATFORM}" = "${platform_macosx}" ]; then
  default_extension="dmg"
fi
if [ "${JDKW_PLATFORM}" = "${platform_windows}" ]; then
  if [ "${JDKW_DIST}" = "${dist_oracle}" ]; then
    default_extension="exe"
  elif [ "${JDKW_DIST}" = "${dist_zulu}" ]; then
    default_extension="zip"
  fi
elif [ "${JDKW_PLATFORM}" = "${platform_linux}" ]; then
  if [ "${JDKW_DIST}" = "${dist_oracle}" ] && [ "${java_major_version}" = "6" ] ; then
    default_extension="bin"
  fi
fi
if [ -z "${JDKW_EXTENSION}" ]; then
  JDKW_EXTENSION=${default_extension}
  log_out "Defaulted to extension ${JDKW_EXTENSION}"
fi
if [ -z "${JDKW_VERBOSE}" ]; then
  curl_options="${curl_options} --silent"
fi

# Special rules
if [ "${JDKW_PLATFORM}" = "${platform_macosx}" ] && [ "${JDKW_DIST}" = "${dist_oracle}" ] && [ "${java_major_version}" = "6" ] ; then
  log_err "JDK${java_major_version} from ${dist_oracle} is not supported on ${platform_macosx}"
  exit 1
fi

# Default JDK locations
if [ "${JDKW_DIST}" = "${dist_oracle}" ]; then
  if [ "${java_major_version}" = "9" ] || [ "${java_major_version}" = "10" ]; then
    latest_jdk_source='http://download.oracle.com/otn-pub/java/jdk/${JDKW_VERSION}+${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}_${JDKW_PLATFORM}_bin.${JDKW_EXTENSION}'
    archived_jdk_source='http://download.oracle.com/otn/java/jdk/${JDKW_VERSION}+${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}_${JDKW_PLATFORM}_bin.${JDKW_EXTENSION}'
  else
    latest_jdk_source='http://download.oracle.com/otn-pub/java/jdk/${JDKW_VERSION}-${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}'
    archived_jdk_source='http://download.oracle.com/otn/java/jdk/${JDKW_VERSION}-${JDKW_BUILD}/${token_segment}jdk-${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}'
  fi
else
  latest_jdk_source='http://cdn.azul.com/zulu/bin/zulu${JDKW_BUILD}-jdk${JDKW_VERSION}-${JDKW_PLATFORM}.${JDKW_EXTENSION}'
  archived_jdk_source=''
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
  last_dir=$(pwd)
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
      curl ${curl_options} -f -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o "${jdk_archive}" "${jdk_url}"
      download_result=$?
    fi

    # 2) Attempt download from latest source
    if [ ${download_result} != 0 ]; then
      eval "jdk_url=\"${latest_jdk_source}\""
      log_out "Attempting download of JDK from ${jdk_url}"
      curl ${curl_options} -f -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -o "${jdk_archive}" "${jdk_url}"
      download_result=$?
    fi

    # 3) Attempt download from archive source (only applies to oracle)
    if [ "${JDKW_DIST}" = "${dist_oracle}" ]; then
      if [ ${download_result} != 0 ]; then
        eval "jdk_url=\"${archived_jdk_source}\""
        log_out "Attempting download of JDK from ${jdk_url}"
        if [ -z "${JDKW_USERNAME}" ]; then
          log_err "No username specified; aborting..."
        elif [ -z "${JDKW_PASSWORD}" ]; then
          log_err "No password specified; aborting..."
        else
          otn_signon "${JDKW_USERNAME}" "${JDKW_PASSWORD}"
          log_out "Initiating authenticated download..."
          curl ${curl_options} -f -k -L -H "User-Agent:${otn_user_agent}" -b "${otn_cookie_jar}" -o "${jdk_archive}" "${jdk_url}"
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

    if [ "${java_major_version}" = "8" ]; then
      jce_archive="jce_policy-${java_major_version}.zip"
    elif [ "${java_major_version}" = "7" ]; then
      jce_archive="UnlimitedJCEPolicyJDK${java_major_version}.zip"
    else
      log_err "JCE not supported for ${JDKW_DIST} major version ${java_major_version}"
      safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
      exit 1
    fi
    jce_url="http://download.oracle.com/otn-pub/java/jce/${java_major_version}/${jce_archive}"

    # Download archive
    log_out "Downloading JCE from ${jce_url}"
    download_result=
    if command -v curl > /dev/null; then
      # Do NOT execute with safe_command; undo operations below on failure
      curl ${curl_options} -j -k -L -H "Cookie: gpw_e24=xxx; oraclelicense=accept-securebackup-cookie;" -o "${jce_archive}" "${jce_url}"
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
    if [ "${java_major_version}" = "8" ]; then
      safe_command "find \"./UnlimitedJCEPolicyJDK${java_major_version}\" -type f -exec cp {} \"${JAVA_HOME}/jre/lib/security\" \\;"
      safe_command "rm -rf \"./UnlimitedJCEPolicyJDK${java_major_version}\""
    elif [ "${java_major_version}" = "7" ]; then
      safe_command "find \"./UnlimitedJCEPolicy\" -type f -exec cp {} \"${JAVA_HOME}/jre/lib/security\" \\;"
      safe_command "rm -rf \"./UnlimitedJCEPolicy\""
    else
      log_err "JCE not supported for ${JDKW_DIST} major version ${java_major_version}"
      safe_command "rm -rf \"${JDKW_TARGET}/${jdkid}\""
      exit 1
    fi
    safe_command "rm \"${jce_archive}\""
  fi

  # Installation complete
  generate_manifest_checksum "${JDKW_TARGET}/${jdkid}" > "${manifest}"
  safe_command "cd ${last_dir}"
fi

# Setup the environment
log_out "Environment:"
if [ -n "${JDKW_VERBOSE}" ]; then
  cat "${JDKW_TARGET}/${jdkid}/environment"
fi
. "${JDKW_TARGET}/${jdkid}/environment"

# Execute the provided command
log_out "Executing: ${command}"
eval ${command}
exit $?
