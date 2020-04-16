#!/usr/bin/env bash
# Just a simple script to install websocketd
# https://github.com/joewalnes/websocketd/wiki/Download-and-install

WEBSOCKET_SRC=https://github.com/joewalnes/websocketd/releases/download
VERSION="0.3.1"

distro=$(cat /etc/os-release | grep -oh "^NAME=.*" | cut -d"=" -f2 | sed 's|\"||g' | cut -d" " -f1)

arch=$(uname -m)

case $distro in
    Ubuntu|Debian)
        pkg_ext=".deb"
        distro_sep="_"
        # Websocket developer is an AMD fanboy...
        arch=$(echo $arch | sed 's|x86_64|amd64|g')
    ;;
    CentOS)
        pkg_ext=".rpm"
        distro_sep="."
    ;;
    *) echo "OS not supported, sorry!"; exit 1
    ;;
esac

filename="websocketd-${VERSION}${distro_sep}${arch}${pkg_ext}"
url=${WEBSOCKET_SRC}/v${VERSION}/${filename}
wget $url

case $distro in
    Ubuntu|Debian)
        sudo dpkg -i $filename;;
    CentOS)
        sudo rpm -i $filename;;
esac

rm websocketd*${pkg_ext}
echo "Websocket succesfully installed!"
