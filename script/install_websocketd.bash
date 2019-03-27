#!/usr/bin/env bash
# Just a simple script to install websocketd
# https://github.com/joewalnes/websocketd/wiki/Download-and-install

WEBSOCKET_SRC=https://github.com/joewalnes/websocketd/releases/download/v0.3.1/websocketd-0.3.1

distro=$(cat /etc/os-release | grep -oh "^NAME=.*" | cut -d"=" -f2 | sed 's|\"||g' | cut -d" " -f1)

case $distro in
    Ubuntu|Debian)
        pkg_ext=".deb"
    ;;
    *) echo "OS not supported, sorry!"; exit 1
    ;;
esac

arch=$(uname -m)
# Websocket developer is an AMD fanboy...
arch=$(echo $arch | sed 's|x86_64|amd64|g')

wget ${WEBSOCKET_SRC}_${arch}${pkg_ext}
sudo dpkg -i websocketd-0.3.1_${arch}${pkg_ext}
rm websocketd-0.3.1_${arch}${pkg_ext}

