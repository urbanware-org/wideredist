#!/usr/bin/env bash

#
# WiDeRedist - Windows Defender definition download and redistribution tool
# Definition download and local redistribution script for Linux and BSD
# Copyright (c) 2025 by Ralf Kilian
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# GitHub: https://github.com/urbanware-org/wideredist
# GitLab: https://gitlab.com/urbanware-org/wideredist
#

version="1.6.4"
timestamp="2025-02-26"

script_dir=$(dirname $(readlink -f $0))
temp_dir=$(mktemp -d)
kernel_name=$(uname -s | tr '[:upper:]' '[:lower:]')
version_update=0

check_requirements() {
    command -v rsync &>/dev/null
    if [ $? -ne 0 ]; then
        error "The required 'rsync' tool does not seem to be installed" 7
    fi

    command -v wget &>/dev/null
    if [ $? -ne 0 ]; then
        use_wget=0
        command -v curl &>/dev/null
        if [ $? -ne 0 ]; then
            error "Neither 'curl' nor 'wget' seems to be installed" 7
        fi
    else
        use_wget=1
    fi
}

check_version() {
    version_temp="${temp_dir}/wideredist_version.tmp"
    rm -f ${version_temp}

    if [ ${use_wget} -eq 1 ]; then
        wget -T ${dl_timeout} -U "${user_agent}" "${version_json}" \
             -O ${version_temp} -q
    else
        curl --connect-timeout ${dl_timeout} -A "${user_agent}" \
             -L "${version_json}" -s -o ${version_temp}
    fi

    if [ -z "${wideredist_update_check}" ] ||
       [ ${wideredist_update_check} -eq 0 ]; then
        rm -f ${definition_path}/version.dat
        version_latest=""
        return
    fi

    version_latest=$(grep "tag_name" ${version_temp} | awk '{ print $2 }' \
                                                     | sed -e "s/^\"//" \
                                                     | sed -e "s/\".*//g")
    if [ "${version}" = "${version_latest}" ]; then
        return
    fi

    version_major=$((sed -e "s/\./\ /g" | awk '{ print $1 }') \
                                        <<< ${version})
    version_minor=$((sed -e "s/\./\ /g" | awk '{ print $2 }') \
                                        <<< ${version})
    version_revis=$((sed -e "s/\./\ /g" | awk '{ print $3 }') \
                                        <<< ${version} | sed -e "s/-.*//g")

    version_major_latest=$((sed -e "s/\./\ /g" | awk '{ print $1 }') \
                                               <<< ${version_latest})
    version_minor_latest=$((sed -e "s/\./\ /g" | awk '{ print $2 }') \
                                               <<< ${version_latest})
    version_revis_latest=$((sed -e "s/\./\ /g" | awk '{ print $3 }' \
                                               | cut -c1) \
                                               <<< ${version_latest})

    if [ -z "${version_major}" ] || \
       [ -z "${version_minor}" ] || \
       [ -z "${version_revis}" ] || \
       [ -z "${version_major_latest}" ] || \
       [ -z "${version_minor_latest}" ] || \
       [ -z "${version_revis_latest}" ]; then
        return
    fi

    if [ ${version_major_latest} -ge ${version_major} ]; then
        if [ ${version_major_latest} -gt ${version_major} ]; then
            version_update=1
        else
            if [ ${version_minor_latest} -ge ${version_minor} ]; then
                if [ ${version_minor_latest} -gt ${version_minor} ]; then
                    version_update=1
                else
                    if [ ${version_revis_latest} -ge ${version_revis} ]; then
                        if [ ${version_revis_latest} -gt ${version_revis} ];
                        then
                            version_update=1
                        fi
                    fi
                fi
            fi
        fi
    fi
}

clean_up() {
    # No need to check if proxy address is set, as non-existing environment
    # variables will be ignored by 'unset' anyway
    unset http_proxy
    unset https_proxy

    rm -fR ${update_path}
    rm -fR ${temp_dir}
}

download_file() {
    weburl="$1"
    outfile="$2"
    file_current="$3"
    file_count="$4"

    download_failed="\e[91mDownload failed.\e[0m"
    download_completed="\e[92mDownload completed.\e[0m"
    download_running="\e[36mDownloading...\e[0m"
    download_file="$(sed -e "s#${update_path}##g" <<< ${outfile})"
    download_count="${file_current} of ${file_count}"
    is_successful=0

    output="  File '${download_file}'\t(${download_count}):"
    echo -ne "${output} ${download_running}\r"

    if [ ${use_wget} -eq 1 ]; then
        wget -T ${dl_timeout} -U "${user_agent}" "${weburl}" \
             -O ${outfile} -q
    else
        curl --connect-timeout ${dl_timeout} -A "${user_agent}" \
             -L "${weburl}" -s -o ${outfile}
    fi
    status_download=$?

    # In case the download succeeded, perform a verification by file size to
    # ensure that the downloaded file has actually been downloaded. In case
    # the link is broken, its size will be significantly less than the actual
    # definition update.
    status_size=1
    if [ ${status_download} -eq 0 ]; then
        if [ -z "${verify_size}" ]; then
            verify_size=100
        fi
        if [ -e "${outfile}" ]; then
            file_size=$(ls -s "${outfile}" | awk '{ print $1 }')
            if [ ${file_size} -lt ${verify_size} ]; then
                log "warning" "File verification failed: '${outfile}'"
                status_verify_fail=1
            else
                status_size=0
            fi
        else
            log "warning" "File verification failed: '${outfile}'"
            status_verify_fail=1
        fi
    fi

    # Remove double slashes from path for log entries
    outfile_log=$(sed -e "s/\/\//\//g" <<< ${outfile})

    if [ ${status_size} -eq 0 ] && [ ${status_download} -eq 0 ]; then
        get_mime_type "${outfile}"
        if [ ${is_executable} -eq 1 ] || [ ${is_executable} -eq 2 ]; then
            echo -e "${output} ${download_completed}"
            log "notice" "Download completed: '${outfile_log}'"
            sha256sum "${outfile}" | awk '{ print $1 }' > "${outfile}.sha256"
            is_successful=1
        else
            echo -e "${output} ${download_failed}"
            reason="MIME type mismatch"
            log "error" "Download failed (${reason}): '${outfile_log}'"
            status_download_fail_count=$((
                ${status_download_fail_count} + 1 ))
        fi
    elif [ ${status_download} -eq 3 ]; then
        echo -e "${output} ${download_failed}"
        reason="I/O error"
        log "error" "Download failed (${reason}): '${outfile_log}'"
        status_download_fail_count=$(( ${status_download_fail_count} + 1 ))
    elif [ ${status_download} -eq 4 ]; then
        echo -e "${output} ${download_failed}"
        reason="network failure"
        log "error" "Download failed (${reason}): '${outfile_log}'"
        status_download_fail_count=$(( ${status_download_fail_count} + 1 ))
    elif [ ${status_download} -eq 5 ]; then
        echo -e "${output} ${download_failed}"
        reason="SSL verification failure"
        log "error" "Download failed (${reason}): '${outfile_log}'"
        status_download_fail_count=$(( ${status_download_fail_count} + 1 ))
    else
        echo -e "${output} ${download_failed}"
        log "error" "Download failed: '${outfile_log}'"
        status_download_fail_count=$(( ${status_download_fail_count} + 1 ))
    fi

    if [ -f ${outfile} ] && [ ${is_successful} -eq 0 ]; then
        rm -f ${outfile}
    fi
}

error() {
    message="$1"
    exit_code="$2"

    # In case of an error the return code must not be zero, even if explicitly
    # set to zero or not given at all
    if [ -z "${exit_code}" ] || [ ${exit_code} -eq 0 ]; then
        exit_code=1
    fi

    echo -e "\e[91merror:\e[0m ${message}."
    log "error" "${message}"
    log "notice" "Exiting"

    clean_up
    exit ${exit_code}
}

get_mime_type() {
    file_name="$1"

    command -v file &>/dev/null
    if [ $? -eq 0 ]; then
        is_executable=0
        file -b "${file_name}" | grep -i "exe" &>/dev/null
        if [ $? -eq 0 ]; then
            is_executable=1
        fi
    else
        # Skip the MIME type check in case the 'file' tool is not installed on
        # the system. Due to the fact that the actual file type cannot be
        # determined without the tool, the value 2 is returned.
        is_executable=2
    fi
}

log() {
    prefix="$1"
    message="$2"
    logger "wideredist[$$]: [${prefix}] ${message}."
}

if [ $# -gt 0 ]; then
    if [ "$1" = "--version" ]; then
        echo "${version}"
        exit 0
    else
        cat <<- end

There are no command-line arguments available (except for '--version'). All
options for the server-side script can be found inside its config file.

Set the options required for your environment inside 'wideredist.conf' (if not
already done) and simply run this script again without any arguments.

end
        error "Unexpected argument '$1'" 254
    fi
fi

# Prevent the script from running multiple times simultaneously. However, when
# performing an automatic update, two instances of the script need to be run
# simultaneously to perform the update process.
already_running=1
if [ ! -f "${temp_dir}/wideredist.upd" ]; then
    for tries in {0..3}; do
        sleep 1
        ps a | grep "bash" | \
               grep "wideredist.sh" | \
               grep -v "$$" | \
               grep -v "grep" &>/dev/null
        if [ $? -eq 1 ]; then
            already_running=0
            break
        fi
    done
    if [ ${already_running} -eq 1 ]; then
        error \
          "Another instance of \e[93mWiDeRedist\e[0m is already running" 255
    fi
fi

rm -fR ${temp_dir}/wideredist*
if [ -f "${script_dir}/wideredist.upd" ]; then
    log "Installing WiDeRedist update"
    source ${script_dir}/wideredist.conf
    if [ -z "${keep_previous}" ]; then
        keep_previous=1
    fi
    mv ${script_dir}/wideredist.upd ${temp_dir}/
    if [ "${keep_previous}" = "1" ]; then
        cat ${script_dir}/wideredist.sh > ${script_dir}/wideredist.sh.bkp
    fi

    if [ -f "${script_dir}/wideredist.conf.default" ] && \
       [ -f "${script_dir}/wideredist.conf.new" ]; then
        rm -f ${script_dir}/wideredist.conf.new
    fi

    # Replace (overwrite to be precise) this script file on the fly and run
    # the new (overwritten) version afterwards. As long as the new version has
    # not finished its duty, the previous script will be idle and exit as soon
    # as the new version is done (both scripts exit at the same time then).
    cat ${temp_dir}/wideredist.upd > ${script_dir}/wideredist.sh
    ${script_dir}/wideredist.sh
    exit
fi

log "notice" "Running WiDeRedist ${version} (${timestamp})"

check_requirements

if [ -f "${script_dir}/wideredist.conf" ]; then
    config_file="${script_dir}/wideredist.conf"
elif [ -f "${script_dir}/wideredist.conf.default" ]; then
    # Fallback with the default config
    cp ${script_dir}/wideredist.conf.default \
       ${script_dir}/wideredist.conf &>/dev/null
    config_file="${script_dir}/wideredist.conf"
else
    error "No configuration file found" 1
fi

# Check if the user has write permissions on the config file. If so, read the
# config file and remove spaces around the equals signs of the config values
# (if existing). Afterwards, write the changes into the config file and parse
# it. Otherwise, the config file will just be read.
touch ${config_file} &>/dev/null
if [ $? -eq 0 ]; then
    cat ${config_file} > ${temp_dir}/wideredist_config.tmp
    (sed -e "/^#/! s/ *= */=/g") < ${temp_dir}/wideredist_config.tmp \
                                 > ${config_file}
fi
source ${config_file}
rm -f ${temp_dir}/wideredist_config.tmp

version_url="${wideredist_url}/releases/latest"
version_json=$(sed -e "s/github\.com/api\.github\.com\/repos/g" \
                   <<< ${version_url})

# Just a supplement for repeating error messages
permission_issue="most likely a permission issue"

if [ ! -z "${proxy_address}" ] && [ ! -z "${route_gateway}" ]; then
    route_target=$(sed -e "s/:.*$//g" <<< ${proxy_address})
    if [[ ${kernel_name} =~ linux ]]; then
        ip route delete ${route_target} via ${route_gateway} &>/dev/null
        ip route add ${route_target} via ${route_gateway} &>/dev/null
        if [ $? -eq 0 ]; then
            route=1
        else
            error \
              "Failed to add the given route, ${permission_issue}" 3
        fi
    else  # BSD
        route delete ${route_target} ${route_gateway} &>/dev/null
        route add ${route_target} ${route_gateway} &>/dev/null
        if [ $? -eq 0 ]; then
            route=1
        else
            error \
              "Failed to add the given route, ${permission_issue}" 3
        fi
    fi
    log "notice" "Added route to '${route_target}' via '${route_gateway}'"
else
    route=0
fi

if [ ! -z "${proxy_address}" ]; then
    export http_proxy="${proxy_address}"
    export https_proxy="${proxy_address}"
    proxy=1
    log "notice" "Using proxy server '${proxy_address}'"
else
    proxy=0
fi

# These are temporary path variables. Downloading takes some time, so before
# the web server provides the latest definitions, they will be downloaded into
# this temporary path. This prevents (or at least reduces) the probability of
# a client-side update failure due to incomplete data.
update_path="${definition_path}/update"
update_path_x86="${update_path}/x86"
update_path_x64="${update_path}/x64"

# Check permissions first. As a matter of fact, this script needs write access
# to the definition path as well as its sub-directories.
if [ -e "${definition_path}" ]; then
    if [ ! -d "${definition_path}" ]; then
        error "Definition path already exists, but is not a directory" 4
    fi

    for object in $(find "${definition_path}"); do
        touch -ca "${object}" &>/dev/null
        if [ $? -ne 0 ]; then
            error \
              "Access denied on '${object}', ${permission_issue}" 5
        fi
    done
fi

# Remove temporary path (if already existing) just to get sure that there are
# no incomplete downloads present or whatever
rm -fR ${update_path} &>/dev/null

# Before downloading anything, ensure the target directories exist
mkdir -p ${definition_path} &>/dev/null
if [ $? -ne 0 ]; then
    error \
      "Failed to create the definition path, ${permission_issue}" 6
fi
mkdir -p ${update_path_x86}
mkdir -p ${update_path_x64}

# Default values for download status and file verification
if [ ! "${skip_x86_download}" = "1" ]; then
    status_download_fail_max=7
else
    status_download_fail_max=4
fi
status_download_fail_count=0
status_verify_fail=0

# Timeout value for download tool
dl_timeout=120

# Start time measurement here
timestamp_start=$SECONDS

# Since version 1.6.3 of WiDeRedist the separate and so called download URL
# file 'wideredist.urls' is required and not optional anymore as before.
#
# This file contains all the Microsoft URLs to the files downloaded by
# WiDeRedist. Before, those could also be set inside the main config file
# 'wideredist.conf', but the URLs from that file will be ignored since that
# version.
#
# The main purpose of the separate download URL file is that if any of the
# Microsoft URLs have changed (quite unlikely, but has happened once before),
# only this file must be replaced and the main config file 'wideredist.conf'
# can remain untainted.
#
# If the download URL file exists it will be updated (if necessary) and if it
# does not, the latest version will be downloaded.
#
# However, this feature must explicitly enabled inside 'wideredist.conf'.
if [ ${url_update} -eq 1 ]; then
    wideredist_gh="https://raw.githubusercontent.com/urbanware-org/wideredist"
    urls_downloaded=0
    urls_updated=0
    urls_error=0
    if [ ! -f "${script_dir}/wideredist.urls" ]; then
        if [ ${use_wget} -eq 1 ]; then
            wget -T ${dl_timeout} -U "${user_agent}" \
                 "${wideredist_gh}/main/server/wideredist.urls" \
                 -O "${script_dir}/wideredist.urls" -q
        else
            curl --connect-timeout ${dl_timeout} -A "${user_agent}" \
                -L "${wideredist_gh}/main/server/wideredist.urls" -s \
                -o "${script_dir}/wideredist.urls"
        fi
        urls_downloaded=1
    else
        if [ ${use_wget} -eq 1 ]; then
            wget -T ${dl_timeout} -U "${user_agent}" \
                 "${wideredist_gh}/main/server/wideredist.urls" \
                 -O "${script_dir}/wideredist.urls.latest" -q
        else
            curl --connect-timeout ${dl_timeout} -A "${user_agent}" \
                -L "${wideredist_gh}/main/server/wideredist.urls" -s \
                -o "${script_dir}/wideredist.urls.latest"
        fi

        diff "${script_dir}/wideredist.urls" \
             "${script_dir}/wideredist.urls.latest" &>/dev/null
        if [ $? -ne 0 ]; then
            rm "${script_dir}/wideredist.urls"
            mv "${script_dir}/wideredist.urls.latest" \
               "${script_dir}/wideredist.urls"
            urls_updated=1
        else
            urls_updated=0
        fi
    fi
fi

source ${script_dir}/wideredist.urls &>/dev/null
if [ $? -eq 0 ]; then
    url_read_error=0
else
    url_read_error=1
fi
rm -f "${script_dir}/wideredist.urls.latest"

# Check if any of download link URLs is missing, as all are required
if [ -z "${mpam_fe_x86}" ] || [ -z "${mpam_fe_x64}" ] || \
   [ -z "${mpas_fe_x86}" ] || [ -z "${mpas_fe_x64}" ] || \
   [ -z "${nis_full_x86}" ] || [ -z "${nis_full_x64}" ] || \
   [ -z "${mpam_d_ind}" ] || [ ${url_read_error} -eq 1 ]; then
    error \
      "At least one Windows Defender definition download link is missing" 2
fi

echo -e "\e[93m"
echo -e "WiDeRedist - Windows Defender definition download and" \
        "redistribution tool"
echo -e "Definition download and local redistribution script"
echo -e "Version ${version} (Released ${timestamp})"
echo -e "Copyright (c) 2025 by Ralf Kilian"
echo -e "\e[0m"

# By default, 'wget' (or 'curl'), which is used to download the definition
# files, checks the certificate of the corresponding servers (accessed via
# HTTPS) from which the files are downloaded, so the use of a dedicated user
# is not necessarily required. Furthermore, the servers from which the files
# are retrieved belong to a trusted source as these are the original servers
# from Microsoft (see 'wideredist.urls' for details).
#
# Due to this, the following block has been commented out.

#if [ $(whoami) = "root" ]; then
#    echo -e "Notice that you are running this script as \e[93mroot\e[0m" \
#            "which is a potential \e[91mrisk\e[0m."
#    echo -e "Due to this, it is strongly recommended to run it with a" \
#            "\e[96mdedicated user\e[0m"
#    echo -e "having the required permissions instead."
#    echo
#    cancel="Press \e[96mCtrl\e[37m+\e[0m\e[96mC\e[0m to \e[91mcancel\e[0m. "
#    for seconds in {10..1}; do
#        if [ ${seconds} -eq 1 ]; then
#            echo -ne "Proceeding in 1 second. ${cancel}  \r"
#        else
#            echo -ne "Proceeding in ${seconds} seconds. ${cancel} \r"
#        fi
#        sleep 1
#    done
#fi

if [ ${url_update} -eq 1 ]; then
    if [ ${urls_downloaded} -eq 1 ]; then
        echo -e "Downloading download link URL file.\n"
        log "notice" "Downloading download link URL file"
    elif [ ${urls_updated} -eq 1 ]; then
        echo -e "Updating download link URL file.\n"
        log "notice" "Updating download link URL file"
    else
        echo -e "Download link URL file is \e[92mup-to-date\e[0m.\n"
        log "notice" "Download link URL file is up-to-date"
    fi
fi

if [ ${route} -eq 1 ]; then
    echo -e "Added route to \e[96m${route_target}\e[0m" \
            "via \e[96m${route_gateway}\e[0m.\n"
fi
if [ ${proxy} -eq 1 ]; then
    echo -e "Using proxy server \e[96m${http_proxy}\e[0m.\n"
fi

echo -e "Starting definition download. Please wait, this may take a while."
log "notice" "Starting definition download"

if [ ! "${skip_x86_download}" = "1" ]; then
    echo -e "\nDownloading \e[96m32-bit\e[0m definition files."
    download_file ${mpam_fe_x86}      ${update_path_x86}/mpam-fe.exe  1 3
    download_file ${mpas_fe_x86}      ${update_path_x86}/mpas-fe.exe  2 3
    download_file ${nis_full_x86}     ${update_path_x86}/nis_full.exe 3 3
else
    echo -e "\nSkipping download of \e[96m32-bit\e[0m definition files."
    rm -f ${definition_path}/x86/*
fi

echo -e "\nDownloading \e[96m64-bit\e[0m definition files."
download_file ${mpam_fe_x64}      ${update_path_x64}/mpam-fe.exe  1 3
download_file ${mpas_fe_x64}      ${update_path_x64}/mpas-fe.exe  2 3
download_file ${nis_full_x64}     ${update_path_x64}/nis_full.exe 3 3

echo -e "\nDownloading \e[96mplatform independent\e[0m definition files."
download_file ${mpam_d_ind}       ${update_path_x64}/mpam-d.exe   1 1

if [ ${status_download_fail_count} -eq ${status_download_fail_max} ]; then
    echo
    error "Aborting as all downloads have failed"
elif [ ${status_download_fail_count} -gt 0 ]; then
    echo -e \
      "\n\e[93mProceeding even though at least one download has failed.\e[0m"
    log "warning" "Proceeding even though at least one download has failed"
else
    log "notice" "Definition downloads have been finished"
fi

if [ ! "${skip_x86_download}" = "1" ]; then
    # The file 'mpam-d.exe' is also required in the definition directory for
    # 32-bit environments. The file is platform independent, so it simply can
    # be copied to 'x86'.
    cp -f ${update_path_x64}/mpam-d.* ${update_path_x86}/
    echo -e "\nDuplicated platform independent file for both platforms."
fi

if [ ${status_verify_fail} -eq 1 ]; then
    echo -e "\nThe verification of at least one file \e[91mfailed\e[0m. If" \
            "the problem persists, the\ndownload link may be broken. Check" \
            "the config and URL file for details."
    log "warning" "Verification of at least one file failed"
fi

echo -e \
  "\nProceeding with update of the definition files for redistribution.\n"
log "notice" "Updating the definition files for redistribution"

# Update the actual definitions. Temporary data will be deleted on exit.
rsync -a ${update_path}/* ${definition_path}/
log "notice" "Definition files have been updated"

check_version
if [ ! -z "${version_latest}" ]; then
    echo "${version_latest}" > ${definition_path}/version.dat
    if [ ${version_update} -eq 1 ]; then
        log "notice" "New WiDeRedist version (${version_latest}) available"
        if [ ${wideredist_update} -eq 1 ]; then
            log "notice" "Automatically updating WiDeRedist"

            # The update process does not need an additional update script.
            # However, the server-side script cannot be updated at this point.
            #
            # In order to update, it is required to download the archive file
            # of the latest version, extract the server-side script from it,
            # change the extension of the file and move (the renamed) file the
            # local directory of WiDeRedist. All these steps are automatically
            # handled by this script.
            #
            # Furthermore, the new config file from the archive will be stored
            # as 'wideredist.conf.default', so the existing config file will
            # be kept untainted.
            #
            # The actual update of the server-side script is performed on the
            # next startup.

            rm -fR ${temp_dir}/wideredist*
            tarfile="wideredist-${version_latest}.tar.gz"

            if [ ${use_wget} -eq 1 ]; then
                wget -T ${dl_timeout} -U "${user_agent}" \
                     ${wideredist_url}/archive/${version_latest}.tar.gz \
                     -O ${temp_dir}/${tarfile} -q
            else
                curl --connect-timeout ${dl_timeout} -A "${user_agent}" \
                     -L "${wideredist_url}/archive/${version_latest}.tar.gz" \
                     -s -o "${temp_dir}/${tarfile}"
            fi

            tar xfv ${temp_dir}/${tarfile} -C ${temp_dir}/ &>/dev/null

            # Client-side files
            client_config="client/Update.ini"
            client_script="client/DefenderUpdate.ps1"
            mkdir -p ${definition_path}/client
            mv ${temp_dir}/wideredist-${version_latest}/${client_script} \
               ${definition_path}/client/
            mv ${temp_dir}/wideredist-${version_latest}/${client_config} \
               ${definition_path}/client/UpdateDefault.ini

            # Server-side files
            server_config="server/wideredist.conf"
            server_script="server/wideredist.sh"
            mv ${temp_dir}/wideredist-${version_latest}/${server_script} \
               ${script_dir}/wideredist.upd
            cat ${temp_dir}/wideredist-${version_latest}/${server_config} \
                > ${script_dir}/wideredist.conf.default

            echo -e "\e[93mWiDeRedist\e[0m will be updated to version" \
                    "\e[93m${version_latest}\e[0m before the next run.\n"
            log "notice" "Start this script once again to finish the update"
        else
            echo -e "Please update \e[93mWiDeRedist\e[0m as version" \
                    "\e[93m${version_latest}\e[0m is available now.\n"
        fi
    fi
fi

if [ ${route} -eq 1 ]; then
    if [ ! -z "${route_remove}" ]; then
        if [ ${route_remove} -eq 1 ]; then
            if [[ ${kernel_name} =~ linux ]]; then
                ip route delete ${route_target} via ${route_gateway}
            else
                route delete ${route_target} ${route_gateway}
            fi
            echo -e "Removed previously added route.\n"
            log "notice" "Removed previously added route"
        fi
    fi
fi

clean_up

# Get current timestamp and consequential elapsed time
timestamp_end=$(( SECONDS - start_time ))
time_elapsed=$(date -ud "@$timestamp_end" +'%H:%M:%S')

echo -e "Process finished."
echo -e "Elapsed time: ${time_elapsed}\n"
log "notice" "Process finished (within ${time_elapsed} seconds)"
log "notice" "Please check the log messages above for errors"
log "notice" "Exiting"