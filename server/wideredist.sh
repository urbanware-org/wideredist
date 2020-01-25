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

version="1.0.9-2"
timestamp="2020-01-25"

download_file() {
    link_id="$1"
    outfile="$2"
    file_current="$3"
    file_count="$4"

    fwlink_url="https://go.microsoft.com/fwlink"
    echo -e "  File '$(sed -e "s#$update_path##g" <<< $outfile)'" \
               "\t(${file_current} of ${file_count}): \c"
    wget "$fwlink_url/?linkid=$link_id" -q -O $outfile &>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "\e[92mDownload completed.\e[0m"
    else
        echo -e "\e[91mDownload failed.\e[0m"
    fi
}

error() {
    message="$1"
    exit_code="$2"

    # In case of an error the return code must not be zero, even if explicitly
    # set or not given.
    if [ "$exit_code" = "" ] || [ $exit_code -eq 0 ]; then
        exit_code=1
    fi
    echo -e "\e[91merror:\e[0m ${message}."
    exit $exit_code
}

script_dir=$(dirname $(readlink -f $0))
kernel_name=$(uname -s | tr '[:upper:]' '[:lower:]')

source $script_dir/wideredist.conf
if [ $? -ne 0 ]; then
    error "No configuration file found"
fi

if [ ! -z "$route_target" ] && [ ! -z "$route_gateway" ]; then
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
else
    route=0
fi

if [ ! -z "$proxy_address" ]; then
    export http_proxy="$proxy_address"
    export https_proxy="$proxy_address"
    proxy=1
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
rm -fR $update_path

# Before downloading anything, ensure the target directories exist
mkdir -p $definition_path
if [ $? -ne 0 ]; then
    error "Failed to create the definition path, maybe a permission issue"
fi
mkdir -p $update_path_x86
mkdir -p $update_path_x64

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

echo -e "Starting definition download. Please wait, this may take a while.\n"

echo -e "Downloading \e[96m32-bit\e[0m definition files."
download_file "207869"                      $update_path_x86/mpam-fe.exe  1 3
download_file "70631"                       $update_path_x86/mpas-fe.exe  2 3
download_file "207869"                      $update_path_x86/nis_full.exe 3 3

echo
echo -e "Downloading \e[96m64-bit\e[0m definition files."
download_file "87341&clcid=0x409"           $update_path_x64/mpam-fe.exe  1 3
download_file "121721&clcid=0x409&arch=x64" $update_path_x64/mpas-fe.exe  2 3
download_file "197094"                      $update_path_x64/nis_full.exe 3 3

echo
echo -e "Downloading \e[96mplatform independent\e[0m definition files."
download_file "211054"                      $update_path_x86/mpam-d.exe   1 1

# The file 'mpam-d.exe' is also required in the definition directory for
# 64-bit environments. The file is platform independent, so it simply can
# be copied to 'x64'.
cp -f $update_path_x86/mpam-d.exe $update_path_x64/

echo -e \
  "\nProceeding with update of the definition files for redistribution.\n"

# Update the actual definitions and remove temporary data
rsync -a $update_path/* $definition_path/
rm -fR $update_path

if [ $route -eq 1 ]; then
    if [ ! -z "$route_remove" ]; then
        if [ $route_remove -eq 1 ]; then
            if [[ $kernel_name =~ linux ]]; then
                ip route delete $route_target via $route_gateway
            else
                route delete $route_target $route_gateway
            fi
            echo -e "Removed previously added route.\n"
        fi
    fi
fi

# No need to check if proxy address is set, as non-existing environment
# variables will be ignored by 'unset' anyway
unset http_proxy
unset https_proxy

echo -e "Process finished.\n"

# EOF
