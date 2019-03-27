#!/usr/bin/env bash
# Just a simple script to install websocketd
# https://github.com/joewalnes/websocketd/wiki/Download-and-install

distro=$(cat /etc/os-release | grep -oh "^NAME=.*" | cut -d"=" -f2 | sed 's|\"||g' | cut -d" " -f1)

case $distro in
    Ubuntu|Debian)
        pkg_manager="apt"
    ;;
    *) echo "OS not supported, sorry!"; exit 1
    ;;
esac

sudo $pkg_manager install apache2

