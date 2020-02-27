#!/usr/bin/env bash
# Just a simple script to install websocketd
# https://github.com/joewalnes/websocketd/wiki/Download-and-install

distro=$(cat /etc/os-release | grep -oh "^NAME=.*" | cut -d"=" -f2 | sed 's|\"||g' | cut -d" " -f1)

case $distro in
    Ubuntu|Debian)
        sudo $pkg_manager install apache2
        sudo systemctl start apache2
        sudo systemctl enable apache2
    ;;
    CentOS)
        sudo yum install httpd
        sudo systemctl start httpd
        sudo systemctl enable httpd
    ;;
    *) echo "OS not supported, sorry!"; exit 1
    ;;
esac

echo "Apache web server succesfully installed!"
