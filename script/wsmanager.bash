#!/usr/bin/env bash
#
#  Copyright (c) 2019-2020      European Spallation Source ERIC
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
#   author  : Felipe Torres González
#             Ross Elliot
#   email   : torresfelipex1@gmail.com
#             ross.elliot@ess.eu
#   date    : 20190321
#   version : 0.0.2
#   basedon : https://github.com/joewalnes/websocketd/wiki/Bash

# Just read any input line from the websocket daemon and launch the script
while read C
do
    cdir=`pwd`
    script=''
    first=''
    args=''

    # does $C have arguments?
    spcs=`echo $C | grep \  | wc -l`
    if [ $spcs -eq 0 ]; then
        first=$C
    else
        # read the first arg to determine what script to run
        IFS=' ' read -a part <<< "$C"

        first=${part[0]}
        #remove the first part of the string, leave all the rest as args to pass to script
        args=${C#${part[0]} }
    fi

    # which script to run?
    if [ "$first" == "mch_config" ]; then
        script='/usr/local/share/mch_config/script/mch_config.bash'
    else
        if [ "$first" == "csentry_handler" ]; then
            script='/usr/local/share/mch_config/script/csentryHandler.py'
        else
            echo "Option not recognized: $C"
        fi
    fi

    if [ ! -z $script ]; then
        eval $script $args
    else
        echo "Option not recognized: $C"
    fi

done
exit
