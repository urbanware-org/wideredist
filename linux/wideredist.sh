#!/bin/bash

# ============================================================================
# WiDeRedist - Windows Defender definition download and redistribution tool
# Definition download and local redistribution script
# Copyright (C) 2019 by Ralf Kilian
# Distributed under the MIT License (https://opensource.org/licenses/MIT)
#
# GitHub: https://github.com/urbanware-org/wideredist
# GitLab: https://gitlab.com/urbanware-org/wideredist
# ============================================================================

version="1.0.5"
timestamp="2019-05-06"

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

script_dir=$(dirname $(readlink -f $0))
source $script_dir/wideredist.conf

if [ ! -z "$route_target" ] && [ ! -z "$route_gateway" ]; then
    ip route add $route_target via $route_gateway
    route=1
else
    route=0
fi

if [ ! -z "$proxy_address" ]; then
    export http_proxy="$proxy_address"
    export https_proxy="$proxy_address"
fi

# These are temporary path variables. Downloading takes some time, so before
# the web server provides the latest definitions, they will be downloaded into
# this temporary path. This prevents (or at least reduces) the probability of
# a client-side update failure due to incomplete data.
update_path="$definition_path/update"
update_path_x86="$update_path/x86"
update_path_x64="$update_path/x64"

# Remove temprary path (if already existing) just to get sure that there are
# no incomplete downloads present or whatever
rm -fR $update_path

# Before downloading anything, ensure the target directories exist
mkdir -p $definition_path
mkdir -p $update_path_x86
mkdir -p $update_path_x64

echo -e "\e[93m"
echo -e "WiDeRedist - Windows Defender definition download and" \
        "redistribution tool"
echo -e "Definition download and local redistribution script"
echo -e "Version $version ($timestamp)"
echo -e "Copyright (C) 2019 by Ralf Kilian"
echo -e "\e[0m"

echo
echo "Starting definition download. Please wait, this may take a while."

echo
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
# 64-bit environments. Obviously, the file seems to be platform independent,
# so it simply can be copied to 'x64' (no need to download twice).
cp -f $update_path_x86/mpam-d.exe $update_path_x64/

echo
echo "Proceeding with update of the definition files for redistribution."

# Update the definitions and remove temporary data
rsync -a $update_path/* $definition_path/
rm -fR $update_path

if [ $route -eq 1 ]; then
    ip route delete $route_target via $route_gateway
fi

# No need to check if proxy address is set, as non-existing environment
# variables will be ignored by 'unset' anyway
unset http_proxy
unset https_proxy

echo
echo "Process finished."
echo

# EOF
