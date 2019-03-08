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
#   date    : 20190306
#   version : 0.0.1

# Configuration variables --------------

SCRIPT_INTERPRETER=expect

# Name of the expect script to use for each step
FWUPDATE=fwupdate.exp
FWCHECK=fwcheck.exp

# Current MCH firmware
CURRENT_VERSION=(2 20 4)

# Port numbers in the MOXA are 40XX
PORT_PREFIX=40

LOG_PREFIX="./log"
LOG_FILE=$LOG_PREFIX/"mch_config_"



function help {
  cat << EOF
Usage: $(basename $0) MOXA_IP <port range> [options]
Arguments:
  - MOXA_IP      -> IP address of the MOXA
  - <port range> -> Port range to apply the configuration.
                    It could be a list of ports or a range:
                    - Port range, from 1 to 16: 1-16
                    - Port list: 1,4,16
                    In order to run in only one port: 4, (don't forget ",")

Options:
-h|--help           Prints this help

EOF
  exit 0
}

function run_script {
  $SCRIPT_INTERPRETER $1 $MOXAIP $2
}

# Error information
# _________________
# Arguments:
# $1 -> Error code (see list below)
# $2 -> Port number in the MOXA
#
# Error codes:
# (1)  :
# (2)  : Failed to retrieve FW version string

function errecho {
  echo -e "\033[101;30m$1\033[0m"
}

function fancyecho {
  echo -e "\033[107;34m$1\033[0m"
}

function print_error {
  case $1 in
    1) errecho "Insuficient arguments passed to the script";;
    2) errecho "40$2::Couldn't retrieve a FW version, please manually check this port.";;
    *) errecho "Unrecognized error code";;
  esac
}


# Check FW of the MCH and update it if needed
# ___________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function update_fw {
  TEMPFILE=`mktemp`

  fancyecho "40$1::Checking FW version"
  run_script $FWCHECK $PORT_PREFIX$1 >  $TEMPFILE
  # Add all outputs to log file
  cat $TEMPFILE
  echo ""
  fw_version=$(grep "MCH FW" $TEMPFILE | egrep -oh "[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}")
  rm $TEMPFILE

  if [ "x$fw_version" == "x" ]; then
    exit 2
  fi

  UPDATE=1
  x1=$(echo ${fw_version} | cut -d"." -f1)
  x2=$(echo ${fw_version} | cut -d"." -f2)
  x3=$(echo ${fw_version} | cut -d"." -f3)
  if [[ $x1 -gt ${CURRENT_VERSION[0]} ]]; then
    UPDATE=0
  elif [[ $x2 -gt ${CURRENT_VERSION[1]} ]]; then
    UPDATE=0
  elif [[ $x3 -ge ${CURRENT_VERSION[2]} ]]; then
    UPDATE=0
  fi

  if [[ $UPDATE -eq 1 ]]; then
    fancyecho "40$1::Writing new FW (Old=$fw_version)...."
    #run_script $FWUPDATE $PORT_PREFIX$1 &
    # Usually it takes around 3 minutes
    #sleep 240
    fancyecho "40$1::FW updated (New=${CURRENT_VERSION[*]})...."
  else
    fancyecho "40$1::FW up to date"
  fi
}


function runner {
  update_fw $1
}

if [[ $# -lt 2 ]]; then help; exit 1; fi
MOXAIP=$1;
PORTS=$2;
# Detect mode: sequence (1) or list (0)
x=$(echo $PORTS | grep ",")
mode=$?
if [[ $mode -eq 1 ]]; then
  fp=$(echo $PORTS | cut -d"-" -f1)
  ep=$(echo $PORTS | cut -d"-" -f2)
else
  # Convert it to an array
  PORTS=$(echo $PORTS | tr "," "\n")
fi
# Remove the first two positional arguments from the buffer
shift 2

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) help;;
    *) echo "Unknown arg: $1"; help;;
  esac
  shift
done

mkdir -p $LOG_PREFIX
logfile="${LOG_FILE}`date "+%y%m%d_%H:%M:%S"`.log"

# Run the expect scripts
if [[ $mode -eq 1 ]]; then      # Sequence mode
  while [ $fp -le $ep ]; do
    runner $fp 2&> $logfile &
    # Retrieve the pid of the process in order to wait for it later
    pids[${i}]=$!
    portn[${i}]=$fp

    fp=$(($fp+1))
  done
else
  k=0
  for i in ${PORTS[*]}; do    # List mode
    runner $i 2&> $logfile &
    # Retrieve the pid of the process in order to wait for it later
    pids[${k}]=$!
    portn[${k}]=$i
    k=$(($k+1))
  done

fi

# Wait for all pids
i=0
for pid in ${pids[*]}; do
    wait $pid
    err=$?
    if [[ $err -ne 0 ]]; then
      print_error $err ${portn[$i]} 2&>> $logfile
    fi
    i=$(($i+1))
done
