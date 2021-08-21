#!/usr/bin/env bash

#
# WiDeRedist - Windows Defender definition download and redistribution tool
# Definition download and local redistribution script for Linux/BSD
# Copyright (C) 2021 by Ralf Kilian
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# GitHub: https://github.com/urbanware-org/wideredist
# GitLab: https://gitlab.com/urbanware-org/wideredist
#

version="1.5.0"
timestamp="2021-08-21"

script_dir=$(dirname $(readlink -f $0))
kernel_name=$(uname -s | tr '[:upper:]' '[:lower:]')
version_update=0

check_command() {
    command -v "$1" &>/dev/null
    if [ $? -ne 0 ]; then
        error "The '$1' tool does not seem to be installed" 7
    fi
}

check_version() {
    version_temp="/tmp/wideredist_version.tmp"
    rm -f $version_temp
    wget -U "$user_agent" "$version_json" -q -O $version_temp

    if [ -z "$wideredist_update_check" ] ||
       [ $wideredist_update_check -eq 0 ]; then
        rm -f $definition_path/version.dat
        version_latest=""
        return
    fi

    version_latest=$(grep "tag_name" $version_temp | awk '{ print $2 }' \
                                                   | sed -e "s/^\"//" \
                                                   | sed -e "s/\".*//g")
    if [ $version = $version_latest ]; then
        return
    fi

    version_major=$((sed -e "s/\./\ /g" | awk '{ print $1 }') \
                                        <<< $version)
    version_minor=$((sed -e "s/\./\ /g" | awk '{ print $2 }') \
                                        <<< $version)
    version_revis=$((sed -e "s/\./\ /g" | awk '{ print $3 }') \
                                        <<< $version | sed -e "s/-.*//g")

    version_major_latest=$((sed -e "s/\./\ /g" | awk '{ print $1 }') \
                                               <<< $version_latest)
    version_minor_latest=$((sed -e "s/\./\ /g" | awk '{ print $2 }') \
                                               <<< $version_latest)
    version_revis_latest=$((sed -e "s/\./\ /g" | awk '{ print $3 }' \
                                               | cut -c1) \
                                               <<< $version_latest)

    if [ $version_major_latest -ge $version_major ]; then
        if [ $version_major_latest -gt $version_major ]; then
            version_update=1
        else
            if [ $version_minor_latest -ge $version_minor ]; then
                if [ $version_minor_latest -gt $version_minor ]; then
                    version_update=1
                else
                    if [ $version_revis_latest -ge $version_revis ]; then
                        if [ $version_revis_latest -gt $version_revis ]; then
                            version_update=1
                        fi
                    fi
                fi
            fi
        fi
    fi
}

download_file() {
    weburl="$1"
    outfile="$2"
    file_current="$3"
    file_count="$4"

    echo -e "  File '$(sed -e "s#$update_path##g" <<< $outfile)'" \
               "\t(${file_current} of ${file_count}): \c"
    wget -U "$user_agent" "$weburl" -q -O $outfile
    status_wget=$?

    # Perform a verification by file size to ensure that the downloaded file
    # has actually been downloaded. In case the link is broken, its size will
    # be significantly less than the actual definition update.
    status_size=1
    if [ -z "$verify_size" ]; then
        verify_size=100
    fi
    file_size=$(ls -s "$outfile" | awk '{ print $1 }')
    if [ $file_size -lt $verify_size ]; then
        log "warning" "File verification failed: '$outfile'"
        status_verify_fail=1
    else
        status_size=0
    fi

    if [ $status_size -eq 0 ] && [ $status_wget -eq 0 ]; then
        echo -e "\e[92mDownload completed.\e[0m"
        log "notice" "Download completed: '$outfile'"
    else
        echo -e "\e[91mDownload failed.\e[0m"
        log "warning" "Download failed: '$outfile'"
    fi
}

error() {
    message="$1"
    exit_code="$2"

    # In case of an error the return code must not be zero, even if explicitly
    # set to zero or not given at all
    if [ -z "$exit_code" ] || [ $exit_code -eq 0 ]; then
        exit_code=1
    fi
    echo -e "\e[91merror:\e[0m ${message}."
    log "error" "${message}"
    log "notice" "Exiting"
    exit $exit_code
}

log() {
    prefix="$1"
    message="$2"
    logger "wideredist[$$]: [$prefix] ${message}."
}

if [ $# -gt 0 ]; then
    if [ "$1" = "--version" ]; then
        echo "$version"
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
if [ ! -f "/tmp/wideredist.upd" ]; then
    ps a | grep "bash" | \
           grep "wideredist.sh" | \
           grep -v "$$" | \
           grep -v "grep" &>/dev/null
    if [ $? -eq 0 ]; then
        error \
          "Another instance of \e[93mWiDeRedist\e[0m is already running" 255
    fi
fi

rm -fR /tmp/wideredist*
if [ -f "$script_dir/wideredist.upd" ]; then
    log "Installing WiDeRedist update"
    source $script_dir/wideredist.conf
    if [ -z "$keep_previous" ]; then
        keep_previous=1
    fi
    mv $script_dir/wideredist.upd /tmp/
    if [ "$keep_previous" = "1" ]; then
        cat $script_dir/wideredist.sh > $script_dir/wideredist.sh.bkp
    fi

    if [ -f "$script_dir/wideredist.conf.default" ] && \
       [ -f "$script_dir/wideredist.conf.new" ]; then
         rm -f $script_dir/wideredist.conf.new
    fi

    # Replace (overwrite to be precise) this script file on the fly and run
    # the new (overwritten) version afterwards. As long as the new version has
    # not finished its duty, the previous script will be idle and exit as soon
    # as the new version is done (both scripts exit at the same time then).
    cat /tmp/wideredist.upd > $script_dir/wideredist.sh
    $script_dir/wideredist.sh
    exit
fi

log "notice" "Running WiDeRedist $version ($timestamp)"

check_command rsync
check_command wget

if [ -f "${script_dir}/wideredist.conf" ]; then
    source ${script_dir}/wideredist.conf
elif [ -f "${script_dir}/wideredist.conf.default" ]; then
    # Fallback with the default config
    source ${script_dir}/wideredist.conf.default
    cp ${script_dir}/wideredist.conf.default \
       ${script_dir}/wideredist.conf &>/dev/null
else
    error "No configuration file found" 1
fi

version_url="${wideredist_url}/releases/latest"
version_json=$(sed -e "s/github\.com/api\.github\.com\/repos/g" \
                   <<< $version_url)

# The separate (and optional) file 'wideredist.urls' is intended to simply
# contain the Microsoft URLs to the files downloaded by WiDeRedist. The main
# purpose of this is that if these URLs have changed (quite unlikely, but has
# happened once before), only this file must be replaced and the configuration
# file 'wideredist.conf' can remain untainted.
if [ -f "${script_dir}/wideredist.urls" ]; then
    # This will overwrite the values given by 'wideredist.conf'
    source ${script_dir}/wideredist.urls
fi

if [ -z "$mpam_fe_x86" ] || [ -z "$mpam_fe_x64" ] || \
   [ -z "$mpas_fe_x86" ] || [ -z "$mpas_fe_x64" ] || \
   [ -z "$nis_full_x86" ] || [ -z "$nis_full_x64" ] || \
   [ -z "$mpam_d_ind" ]; then
    error \
      "At least one Windows Defender definition download link is missing" 2
fi

# Just a supplement for repeating error messages
permission_issue="most likely a permission issue"

if [ ! -z "$proxy_address" ] && [ ! -z "$route_gateway" ]; then
    route_target=$(sed -e "s/:.*$//g" <<< $proxy_address)
    if [[ $kernel_name =~ linux ]]; then
        ip route delete $route_target via $route_gateway &>/dev/null
        ip route add $route_target via $route_gateway &>/dev/null
        if [ $? -eq 0 ]; then
            route=1
        else
            error \
              "Failed to add the given route, $permission_issue" 3
        fi
    else  # BSD
        route delete $route_target $route_gateway &>/dev/null
        route add $route_target $route_gateway &>/dev/null
        if [ $? -eq 0 ]; then
            route=1
        else
            error \
              "Failed to add the given route, $permission_issue" 3
        fi
    fi
    log "notice" "Added route to '$route_target' via '$route_gateway'"
else
    route=0
fi

if [ ! -z "$proxy_address" ]; then
    export http_proxy="$proxy_address"
    export https_proxy="$proxy_address"
    proxy=1
    log "notice" "Using proxy server '$proxy_address'"
else
    proxy=0
fi

# These are temporary path variables. Downloading takes some time, so before
# the web server provides the latest definitions, they will be downloaded into
# this temporary path. This prevents (or at least reduces) the probability of
# a client-side update failure due to incomplete data.
update_path="$definition_path/update"
update_path_x86="$update_path/x86"
update_path_x64="$update_path/x64"

# Check permissions first. As a matter of fact, this script needs write access
# to the definition path as well as its sub-directories.
if [ -e "$definition_path" ]; then
    if [ ! -d "$definition_path" ]; then
        error "Definition path already exists, but is not a directory" 4
    fi

    for object in $(find "$definition_path"); do
        touch -ca "$object"
        if [ $? -ne 0 ]; then
            error \
              "Access denied on '$object', $permission_issue" 5
        fi
    done
fi

# Remove temporary path (if already existing) just to get sure that there are
# no incomplete downloads present or whatever
rm -fR $update_path &>/dev/null

# Before downloading anything, ensure the target directories exist
mkdir -p $definition_path &>/dev/null
if [ $? -ne 0 ]; then
    error \
      "Failed to create the definition path, $permission_issue" 6
fi
mkdir -p $update_path_x86
mkdir -p $update_path_x64

# Default value for file verification
status_verify_fail=0

# Start time measurement here
timestamp_start="$(date -u +%s)"

echo -e "\e[93m"
echo -e "WiDeRedist - Windows Defender definition download and" \
        "redistribution tool"
echo -e "Definition download and local redistribution script"
echo -e "Version $version (Released $timestamp)"
echo -e "Copyright (C) 2021 by Ralf Kilian"
echo -e "\e[0m"

if [ $route -eq 1 ]; then
    echo -e "Added route to \e[96m$route_target\e[0m" \
            "via \e[96m$route_gateway\e[0m.\n"
fi
if [ $proxy -eq 1 ]; then
    echo -e "Using proxy server \e[96m$http_proxy\e[0m.\n"
fi

echo -e "Starting definition download. Please wait, this may take a while."
log "notice" "Starting definition download"

if [ ! "$skip_x86_download" = "1" ]; then
    echo -e "\nDownloading \e[96m32-bit\e[0m definition files."
    download_file $mpam_fe_x86      $update_path_x86/mpam-fe.exe  1 3
    download_file $mpas_fe_x86      $update_path_x86/mpas-fe.exe  2 3
    download_file $nis_full_x86     $update_path_x86/nis_full.exe 3 3
else
    echo -e "\nSkipping \e[96m32-bit\e[0m definition files."
    rm -f $update_path_x86/*
fi

echo -e "\nDownloading \e[96m64-bit\e[0m definition files."
download_file $mpam_fe_x64      $update_path_x64/mpam-fe.exe  1 3
download_file $mpas_fe_x64      $update_path_x64/mpas-fe.exe  2 3
download_file $nis_full_x64     $update_path_x64/nis_full.exe 3 3

echo -e "\nDownloading \e[96mplatform independent\e[0m definition files."
download_file $mpam_d_ind       $update_path_x64/mpam-d.exe   1 1

log "notice" "Definition downloads have been finished"

if [ ! "$skip_x86_download" = "1" ]; then
    # The file 'mpam-d.exe' is also required in the definition directory for
    # 64-bit environments. The file is platform independent, so it simply can
    # be copied to 'x64'.
    cp -f $update_path_x64/mpam-d.exe $update_path_x86/
    echo -e "\nDuplicated platform independent file for both platforms."
fi

if [ $status_verify_fail -eq 1 ]; then
    echo -e "\nThe verification of at least one file \e[91mfailed\e[0m. If" \
            "the problem persists, the\ndownload link may be broken. Check" \
            "the config and URL file for details."
fi

echo -e \
  "\nProceeding with update of the definition files for redistribution.\n"
log "notice" "Updating the definition files for redistribution"

# Update the actual definitions and remove temporary data
rsync -a $update_path/* $definition_path/
rm -fR $update_path
log "notice" "Definition files have been updated"

check_version
if [ ! -z "$version_latest" ]; then
    echo "$version_latest" > $definition_path/version.dat
    if [ $version_update -eq 1 ]; then
        log "notice" "New WiDeRedist version ($version_latest) available"
        if [ $wideredist_update -eq 1 ]; then
            log "notice" "Automatically updating WiDeRedist"
            rm -fR /tmp/wideredist*
            tarfile="wideredist-${version_latest}.tar.gz"

            # The update process does not need an additional update script or
            # whatsoever. However, the server-side script cannot be updated at
            # this point.
            #
            # Due to this, it is required to download the archive file of the
            # latest version, extract the server-side script from it, change
            # the extension of the file and move (the renamed) file the local
            # directory of WiDeRedist.
            #
            # Furthermore, the new config file from the archived will be
            # stored as new 'wideredist.conf.default', so the existing config
            # file will be kept untainted.
            #
            # So, the following code simply prepares the update for the
            # server-side script, but the actual update process will be
            # performed when the script is being run again.
            wget -U "$user_agent" \
                 "$wideredist_url/archive/${version_latest}.tar.gz" -q \
                 -O /tmp/$tarfile
            tar xfv /tmp/$tarfile -C /tmp/ &>/dev/null
            mkdir -p $definition_path/client
            mv /tmp/wideredist-$version_latest/client/DefenderUpdate.ps1 \
               $definition_path/client/
            mv /tmp/wideredist-$version_latest/client/Update.ini \
               $definition_path/client/UpdateDefault.ini
            mv /tmp/wideredist-$version_latest/server/wideredist.sh \
               $script_dir/wideredist.upd
            cat /tmp/wideredist-$version_latest/server/wideredist.conf \
               > $script_dir/wideredist.conf.default

            echo -e "\e[93mWiDeRedist\e[0m will be updated to version" \
                    "\e[93m$version_latest\e[0m before the next run.\n"
            log "notice" "Start this script once again to finish the update"
        else
            echo -e "Please update \e[93mWiDeRedist\e[0m as version" \
                    "\e[93m$version_latest\e[0m is available now.\n"
        fi
    fi
fi

if [ $route -eq 1 ]; then
    if [ ! -z "$route_remove" ]; then
        if [ $route_remove -eq 1 ]; then
            if [[ $kernel_name =~ linux ]]; then
                ip route delete $route_target via $route_gateway
            else
                route delete $route_target $route_gateway
            fi
            echo -e "Removed previously added route.\n"
            log "notice" "Removed previously added route"
        fi
    fi
fi

# No need to check if proxy address is set, as non-existing environment
# variables will be ignored by 'unset' anyway
unset http_proxy
unset https_proxy

# Get current timestamp and consequential elapsed time
timestamp_end="$(date -u +%s)"
time_elapsed=$(( $timestamp_end - $timestamp_start ))

rm -fR /tmp/wideredist*
echo -e "Process finished."
echo -e "Elapsed time: $time_elapsed seconds\n"
log "notice" "Process finished (within $time_elapsed seconds)"
log "notice" "Please check the log messages above for errors"
log "notice" "Exiting"

# EOF
