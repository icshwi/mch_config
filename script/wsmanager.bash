#!/usr/bin/env bash
#
#  Copyright (c) 2019           European Spallation Source ERIC
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
#   email   : torresfelipex1@gmail.com
#   date    : 20190321
#   version : 0.0.1
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
        script='mch_config.bash'
    else
        echo "Option not recognized: $C"
    fi

    if [ ! -z $script ]; then
        eval $script $args
    else
        echo "Option not recognized: $C"
    fi

done
exit
