#!/bin/bash
#
#  Copyright (c) 2018 - 2019  European Spallation Source ERIC
#
#  The program is free software: you can redistribute
#  it and/or modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation, either version 2 of the
#  License, or any newer version.
#
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License along with
#  this program. If not, see https://www.gnu.org/licenses/gpl-2.0.txt
#
# Author  : Jeong Han Lee
# email   : han.lee@esss.se
# Date    : Monday, March  4 12:55:28 CET 2019
# version : 0.0.1

declare -gr SC_SCRIPT="$(realpath "$0")"
declare -gr SC_SCRIPTNAME=${0##*/}
declare -gr SC_TOP="${SC_SCRIPT%/*}"
declare -g SC_VERSION="v0.0.1"

EXIST=1
NON_EXIST=0

declare -gr DEFAULT_MOXA_IP="10.0.5.173"
declare -gr DEFAULT_MOXA_PORT="4016"
declare -gr DEFAULT_REQ_VERSION="3.0.4"


function pushd { builtin pushd "$@" > /dev/null; }
function popd  { builtin popd  "$@" > /dev/null; }


function die
{
    error=${1:-1}
    ## exits with 1 if error number not given
    shift
    [ -n "$*" ] &&
	printf "%s%s: %s\n" "$scriptname" ${version:+" ($version)"} "$*" >&2
    exit "$error"
}



function usage
{
    {
	echo "";
	echo "Usage    : $0 [-m <moxa_ip_addr>] [-p <moxa_port_num>] [-u <MTCA_crate_type>] setup" ;
	echo "";
	echo "               -m : default ${DEFAULT_TARGET_PATH}"
	echo "               -p : default ${DEFAULT_BASE_VERSION}"
	echo "               -u : default ${DEFAULT_REQ_VERSION}"
	echo "";
	echo " bash $0 -m ${DEFAULT_MOXA_IP} -p 4016 -u 3 setup"
	echo ""
	
    } 1>&2;
    exit 1; 
}



options=":m:p:u:y"
ANSWER="NO"



while getopts "${options}" opt; do
    case "${opt}" in
        m) MOXAIP=${OPTARG}          ;;
	p) MOXAPORT=${OPTARG}    ;;
      	u) CRATETYPE=${OPTARG} ;;
	y) ANSWER="YES"              ;;
   	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    exit 1
	    ;;
	h)
	    usage
	    ;;
	\?)
	    echo "Invalid option: -$OPTARG" >&2
	    exit
	    ;;
    esac
done
shift $((OPTIND-1))

