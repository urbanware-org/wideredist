#!/usr/bin/env bash

# ============================================================================
# WiDeRedist - Windows Defender definition download and redistribution tool
# Definition download and local redistribution script for Linux/BSD
# Copyright (C) 2020 by Ralf Kilian
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# GitHub: https://github.com/urbanware-org/wideredist
# GitLab: https://gitlab.com/urbanware-org/wideredist
# ============================================================================

version="1.2.9"
timestamp="2020-03-16"

script_dir=$(dirname $(readlink -f $0))
kernel_name=$(uname -s | tr '[:upper:]' '[:lower:]')

rm -fR /tmp/wideredist*
if [ -f "$script_dir/wideredist.upd" ]; then
    logger "wideredist[$$]: [notice] Installing WiDeRedist update."
    source $script_dir/wideredist.conf
    if [ $? -ne 0 ]; then
        keep_previous=1
    fi
    mv $script_dir/wideredist.upd /tmp/
    if [ $keep_previous -eq 1 ]; then
        cat $script_dir/wideredist.sh > $script_dir/wideredist.bkp
    fi
    cat /tmp/wideredist.upd > $script_dir/wideredist.sh
    $script_dir/wideredist.sh
    exit
fi

download_file() {
    weburl="$1"
    outfile="$2"
    file_current="$3"
    file_count="$4"

    echo -e "  File '$(sed -e "s#$update_path##g" <<< $outfile)'" \
               "\t(${file_current} of ${file_count}): \c"
    wget -U "$user_agent" "$weburl" -q -O $outfile &>/dev/null
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
    # set or not given
    if [ "$exit_code" = "" ] || [ $exit_code -eq 0 ]; then
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

# Just check for '--version' argument, everything else will be ignored
grep "\-\-version" <<< $@ &>/dev/null
if [ $? -eq 0 ]; then
    echo "$version"
    exit 0
fi

log "notice" "Running WiDeRedist $version ($timestamp)"
source $script_dir/wideredist.conf
if [ $? -ne 0 ]; then
    error "No configuration file found"
fi

if [ ! -z "$proxy_address" ] && [ ! -z "$route_gateway" ]; then
    route_target=$(sed -e "s/:.*$//g" <<< $proxy_address)
    if [[ $kernel_name =~ linux ]]; then
        ip route delete $route_target via $route_gateway &>/dev/null
        ip route add $route_target via $route_gateway &>/dev/null
        if [ $? -eq 0 ]; then
            route=1
        else
            error "Failed to add the given route, maybe a permission issue"
        fi
    else  # BSD
        route delete $route_target $route_gateway &>/dev/null
        route add $route_target $route_gateway &>/dev/null
        if [ $? -eq 0 ]; then
            route=1
        else
            error "Failed to add the given route, maybe a permission issue"
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
        error "Definition path already exists, but is not a directory"
    fi

    for object in $(find "$definition_path"); do
        touch -ca "$object"
        if [ $? -ne 0 ]; then
            error "Access denied on '$object', please set correct permissions"
        fi
    done
fi

# Remove temporary path (if already existing) just to get sure that there are
# no incomplete downloads present or whatever
rm -fR $update_path &>/dev/null

# Before downloading anything, ensure the target directories exist
mkdir -p $definition_path &>/dev/null
if [ $? -ne 0 ]; then
    error "Failed to create the definition path, maybe a permission issue"
fi
mkdir -p $update_path_x86
mkdir -p $update_path_x64

# Default value for file verification
status_verify_fail=0

# WiDeRedist update check related
version_url="https://github.com/urbanware-org/wideredist/releases/latest"
version_temp="/tmp/wideredist_version.tmp"

echo -e "\e[93m"
echo -e "WiDeRedist - Windows Defender definition download and" \
        "redistribution tool"
echo -e "Definition download and local redistribution script"
echo -e "Version $version (Released $timestamp)"
echo -e "Copyright (C) 2020 by Ralf Kilian"
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

echo -e "\nDownloading \e[96m32-bit\e[0m definition files."
download_file $mpam_fe_x86      $update_path_x86/mpam-fe.exe  1 3
download_file $mpas_fe_x86      $update_path_x86/mpas-fe.exe  2 3
download_file $nis_full_x86     $update_path_x86/nis_full.exe 3 3

echo -e "\nDownloading \e[96m64-bit\e[0m definition files."
download_file $mpam_fe_x64      $update_path_x64/mpam-fe.exe  1 3
download_file $mpas_fe_x64      $update_path_x64/mpas-fe.exe  2 3
download_file $nis_full_x64     $update_path_x64/nis_full.exe 3 3

echo -e "\nDownloading \e[96mplatform independent\e[0m definition files."
download_file $mpam_d_ind       $update_path_x86/mpam-d.exe   1 1

log "notice" "Definition downloads have been finished"

# The file 'mpam-d.exe' is also required in the definition directory for
# 64-bit environments. The file is platform independent, so it simply can
# be copied to 'x64'.
cp -f $update_path_x86/mpam-d.exe $update_path_x64/
echo -e "\nDuplicated platform independent file for both platforms."

if [ $status_verify_fail -eq 1 ]; then
    echo -e "\nThe verification of at least one file \e[91mfailed\e[0m. If" \
            "the problem persists, the\ndownload link may be broken. See" \
            "the config file for details."
fi

echo -e \
  "\nProceeding with update of the definition files for redistribution.\n"
log "notice" "Updating the definition files for redistribution"

# Update the actual definitions and remove temporary data
rsync -a $update_path/* $definition_path/
rm -fR $update_path
log "notice" "Definition files have been updated"

rm -f $version_temp
wget -U "$user_agent" "$version_url" -q -O $version_temp &>/dev/null
version_latest=$(grep "wideredist-" $version_temp \
                                    | head -n 1 \
                                    | sed -e "s/.*wideredist-//g" \
                                    | sed -e "s/\ .*//g")
if [ ! -z "$version_latest" ]; then
    echo "$version_latest" > $definition_path/version.dat
    if [ ! "$version" = "$version_latest" ]; then
        log "notice" "New WiDeRedist version ($version_latest) available"
        if [ $wideredist_update -eq 1 ]; then
            log "notice" "Automatically updating WiDeRedist"
            rm -fR /tmp/wideredist*
            tarfile="wideredist-${version_latest}.tar.gz"

            wget -U "$user_agent" \
                 "$wideredist_url/archive/${version_latest}.tar.gz" -q \
                 -O /tmp/$tarfile &>/dev/null
            tar xfv /tmp/$tarfile -C /tmp/ &>/dev/null
            mkdir -p $definition_path/client
            mv /tmp/wideredist-$version_latest/client/*.ps1 \
               $definition_path/client
            mv /tmp/wideredist-$version_latest/server/wideredist.sh \
               $script_dir/wideredist.upd
            rm -fR /tmp/wideredist*

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

echo -e "Process finished.\n"
log "notice" "Process finished. Check log messages above for errors"
log "notice" "Exiting"

# EOF
