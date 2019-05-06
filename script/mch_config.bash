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
#             Jeong Han Lee
#   email   : torresfelipex1@gmail.com
#             jeonghan.lee@gmail.com
#
#   date    : Monday, April 15 15:08:12 CEST 2019
#
#   version : 0.0.4

SCRIPT_INTERPRETER=expect

# Current MCH firmware
CURRENT_VERSION=(2 20 4)

# Port numbers in the MOXA are 40XX
PORT_PREFIX=40

# Flags for the different configuration steps: 1 -> enable the step
FW_UPDATE=1
DHCP_CFG=1
MCH_CFG=1
CLK_CFG=0
CFG_CHECK=0

UPDATE_SLEEP=300
SLEEP=30

# Flag to control the log system in the application
# Valid options:
# -> "WEB" : All messages will contain extra information for the web interface
# -> "USER" : Only human readable information in the output messages
# -> "" : Raw format
LOG=""


function brief_help {
  cat << EOF
$(basename $0) MOXA_IP <port range> <form factor> [options]
Use --help to get a detailed information about how to use the tool
EOF
  exit 0
}

function help {
  cat << EOF
Usage: $(basename $0) MOXA_IP <port range> <form factor> [options]
Arguments:
  MOXA_IP        -> IP address of the MOXA
  <port range>   -> Port range to apply the configuration.
                    It could be a list of ports or a range:
                    - Port range, from 1 to 16: 1-16
                    - Port list: 1,4,16
                    In order to run in only one port: 4, (don't forget ",")
  <form factor>  -> Crate form factor. Valid options are: 3U, 5U or 9U.

Options:
  -h|--help      -> Prints this help
  -s|--steps     -> Specify wich steps to run:
                  1 -> DHCP network configuration (default)
                  2 -> FW update (default)
                  3 -> Standard MCH configuration (default)
                  4 -> Clock configuration
                  5 -> Check the configuration
                  By default, the script is executed with options: 1,2,3,5
  -p|--prefix    -> Source prefix for the tool. By default is "../".
  -l|--log       -> Enable an human readable log
  -w|--web       -> Enable web log (interface with the WEBUI)
Examples:
Run the script to update FW only in the port 4010:
    mch_config.sh 10.0.5.173 10, 3U -s 1
Run the script to configure DHCP in ports 10 to 14:
    mch_config.sh 10.0.5.173 10-14 3U --steps 2
Run the script with the default steps on ports 10,11 and 15:
    mch_config.sh 10.0.5.173 10,11,15 9U

EOF
  exit 0
}

# Just another wrapper function
# Arguments:
# $1 -> Port number (just last 2 digits).
# $2 -> Source script (Expect) to run
function run_script {
    local src_script=$1;
    local portN=$2;
    $SCRIPT_INTERPRETER $src_script $MOXAIP $PORT_PREFIX$portN
}

# Error information
# _________________
# Arguments:
# $1 -> Error code (see list below)
# $2 -> Port number in the MOXA
#
# Error codes:
# (1)  : Generic error
# (2)  : Failed to retrieve FW version string
# (3)  : Insuficient arguments
# (4)  : Error in the MCH configuration check

function print_error {
  case $1 in
    1) $wecho "Generic error, check the logs" $2 $3;;
    2) $wecho "Couldn't retrieve a FW version, please manually check this port." $2 $3;;
    3) $wecho "Insuficient arguments passed to the script" $2 $3;;
    4) $wecho "MCH configuration is not properly setup" $2 $3;;
    5) $wecho "Wrong step argument" $2 $3;;
    *) $wecho "Unrecognized error code" $2 $3;;
  esac
}

# echo wrapper to include extra information for the web interface
# _______________________________________________________________
# Arguments:
# 1 -> message content
# 2 -> message type (see description in the beginning of the source code)
# 3 -> message destination (see description in the beginning)
function webecho {
  local msg=$1
  local type=$2
  local dest=$3
  echo "$INIT_TAG$type::@$3::$msg$END_TAG"
}

# echo wrapper to beautify a little bit the output messages
# _________________________________________________________
# 1 -> message content
# 2 -> type: "err" or "inf" or "dbg"
# 3 -> port number
function userecho {
  local msg=$1
  local type=$2
  local port="@"$3

  if [[ $port = "@ALL" ]]; then port="";fi
  if [[ $type = "inf" ]]; then format="107;34";
  elif [[ $type = "dbg" ]]; then format="94"
  else format="101;30"; fi

  echo -e "\033[${format}m$msg $port\033[0m"
}

function set_portN {

    local portN=$1; shift;

    if [[ ${#portN} -lt 2 ]] ; then
      portN="00${portN}"
      portN="${portN: -2}"
    fi

    echo $portN;
}

# Get which steps to run
function step_parser {
  # First diable all
  FW_UPDATE=0
  DHCP_CFG=0
  MCH_CFG=0
  CLK_CFG=0
  arg_list=$(echo $1 | tr "," "\n")
  for arg in ${arg_list[*]}; do
      case "$arg" in
      1) DHCP_CFG=1;;
      2) FW_UPDATE=1;;
      3) MCH_CFG=1;;
      4) CLK_CFG=1;;
      5) CFG_CHECK=1;;
      *) print_error 5 "err" "@ALL"
    esac
  done
}

# Check FW of the MCH and update it if needed
# ___________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 32)

function update_fw {
  local FW_TEMPFILE=$(mktemp -q --suffix=_fw)

  port=$(set_portN $1)

  $wecho "Init FW version checking" "$INFO_TAG" "40$port"
  run_script $FWCHECK_SRC $port > $FW_TEMPFILE
  fw_version=$(grep "MCH FW" $FW_TEMPFILE | egrep -oh "[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}")
  $wecho "FW tempfile:$FW_TEMPFILE" "$DBG_TAG" "40$port"
  $wecho "Current FW version:$fw_version" "$DBG_TAG" "40$port"
  $wecho "Expected FW version:${CURRENT_VERSION[*]}" "$DBG_TAG" "40$port"
  rm $FW_TEMPFILE

  if [ "x$fw_version" == "x" ]; then
    print_error 2 "err" "40$port"
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
    $wecho "Updating FW version" "$INFO_TAG" "40$port"
    run_script $FWUPDATE_SRC $port >> /dev/null
    # Usually it takes around 3 minutes
    sleep $UPDATE_SLEEP
    $wecho "Updated FW version" "$INFO_TAG" "40$port"
  else
    $wecho "FW version up to date" "$INFO_TAG" "40$port"
  fi

  $wecho "End FW version checking" "$INFO_TAG" "40$port"
}

# Configure the MCH to accept an IP address from a DHCP server
# ____________________________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function dhcp_conf {
  local port=$(set_portN $1)
  $wecho "Init DCHP configuration" "$INFO_TAG" "40$port"
  run_script $DHCPCFG_SRC $port >> /dev/null
  $wecho "End DCHP configuration" "$INFO_TAG" "40$port"
  sleep $SLEEP
}

# Write the standard configuration
# ________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function mch_conf {
  local port=$(set_portN $1)
  $wecho "Init MCH general configuration" "$INFO_TAG" "40$port"
  run_script $MCHCFG_SRC $port >> /dev/null
  $wecho "End MCH general configuration" "$INFO_TAG" "40$port"
  sleep $SLEEP
}

# Write the clock configuration
# _____________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)
function clk_conf {
  local port=$(set_portN $1)
  $wecho "Init MCH clock configuration" "$INFO_TAG" "40$port"
  local CLK_SRC="CLK_SRC_$FORMFACTOR"
  run_script ${!CLK_SRC} $port >> /dev/null
  $wecho "End MCH clock configuration" "$INFO_TAG" "40$port"
  sleep $SLEEP
}

# Check the written configuration
# _______________________________
#
#
function err_check {
  local port=$(set_portN $1)
  # Not implemented
  $wecho "Error checking not implemented" "$ERR_TAG" "40$port"
  # RUNNING_CFG=`mktemp`
  # CMP1=`mktemp`
  # CMP2=`mktemp`
  # # Now the run_script wrapper sends by default the output to /dev/null,
  # # and here we really need that.
  # $SCRIPT_INTERPRETER $CFGCHECK_SRC $MOXAIP $PORT_PREFIX$1 > $RUNNING_CFG
  # # Delete output from expect script. Leave the configuration file.
  # sed -i '/===  Text/,$!d' $RUNNING_CFG
  # # Remove "===Text"
  # sed -i '1,2d' $RUNNING_CFG
  # # Last 2 lines need to be removed (promt and something else)
  # sed -i "$(($(wc -l < ${RUNNING_CFG})-3)),\$d" $RUNNING_CFG
  # #BUG: Sometimes there's still one blank line in the begining of the file.
  # # I'm sorry but I don't know a clean way to do this:
  # # awk '/^$/ && !f{f=1;next}1' ${TEMPFILE}_2 > ${TEMPFILE}
  # local CFG_FILE="GOLDEN_CFG_${FORMFACTOR}"
  # # In oder to avoid cumbersome missmatches, it's better to remove all
  # # commented and blank lines before the comparison.
  # grep -o '^[^#]*' ${!CFG_FILE} > $CMP1
  # grep -o '^[^#]*' $RUNNING_CFG > $CMP2
  # diff --strip-trailing-cr --ignore-blank-lines $CMP1 $CMP2
  # retvalue=$?
  # #rm $TEMPFILE
  # #rm ${TEMPFILE}_2
  # if [[ $retvalue -ne 0 ]]; then exit 4; fi
  # port=$(printf "%02d" $1)
  # fancyecho "\n40$port::The configuration of the MCH is OK"
  # sleep $SLEEP
}

# Check step flags and run the scripts on a specific port
function runner {
  if [[ $DHCP_CFG -eq 1 ]];   then dhcp_conf  $1; fi
  if [[ $FW_UPDATE -eq 1 ]];  then update_fw  $1; fi
  if [[ $MCH_CFG -eq 1 ]];    then mch_conf   $1; fi
  if [[ $CLK_CFG -eq 1 ]];    then clk_conf   $1; fi
  if [[ $CFG_CHECK -eq 1 ]];  then err_check  $1; fi
}

# Define the path for the source files.
# _______________________________

function var_definition {
  CFG_PREFIX=${SRC_PREFIX}/src
  EXPECT_PREFIX=${SRC_PREFIX}/expect

  # The real magic happens inside a set of script written in Expect language
  # Following variables store the name of the individual steps:
  #
  # Script to check & update the firmware of the MCH CPU
  FWCHECK_SRC=$EXPECT_PREFIX/fwcheck.exp
  FWUPDATE_SRC=$EXPECT_PREFIX/fwupdate.exp

  # Script to write general configuration and check it
  MCHCFG_SRC=$EXPECT_PREFIX/mchconf.exp
  CFGCHECK_SRC=$EXPECT_PREFIX/cfgcheck.exp

  #declare -A GOLDEN_CFG
  GOLDEN_CFG_3U=$CFG_PREFIX/GOLDEN_cfg_3u.txt
  GOLDEN_CFG_9U=$CFG_PREFIX/GOLDEN_cfg_9u.txt
  GOLDEN_CFG_5U=$CFG_PREFIX/GOLDEN_cfg_mini.txt

  # Script to set DHCP configuration
  DHCPCFG_SRC=$EXPECT_PREFIX/dhcp.exp

  # Scripts that load the clock configuration
  #declare -A CLK_SRC
  CLK_SRC_3U=$EXPECT_PREFIX/clock_update_3u.exp
  CLK_SRC_5U=$EXPECT_PREFIX/clock_update_mini.exp
  CLK_SRC_9U=$EXPECT_PREFIX/clock_update_9u.exp

  INIT_TAG="^"
  END_TAG=";;"
  INFO_TAG="inf"
  DBG_TAG="dbg"
  ERR_TAG="err"

  wecho=echo
  if [[ $LOG = "USER" ]]; then wecho=userecho;
  elif [[ $LOG = "WEB" ]]; then wecho=webecho; fi
}

# Start of the script magic
# _________________________
start=`date +%s`

if [[ $# -lt 1 ]]; then brief_help; exit 1;
elif [[ $1 = "--help" ]] || [[ $1 = "-h" ]]; then help; exit 1;
elif [[ $# -lt 3 ]]; then print_error 1; exit 1;
fi

MOXAIP=$1
PORTS=$2
rawports=$2
FORMFACTOR=$3

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
shift 3

# Argument parsing
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) help;;
    -s|--steps) step_parser $2;shift;;
    -p|--prefix) SRC_PREFIX=$2;shift;;
    -l|--log) LOG="USER";;
    -w|--web) LOG="WEB";;
    *) $wecho "Unknown arg: $1"; help;;
  esac
  shift
done

# We need to properly define the path to all the source files used by this
# script. We need to bear in mind that the script may be placed locally in
# the repository folder, or may be installed system wide.
if [ -z $SRC_PREFIX ]; then
  SRC_PREFIX=$(realpath $0);
  SRC_PREFIX=$(echo $SRC_PREFIX | sed "s|${0##*/}|../|g")
fi
var_definition

$wecho "MCH configuration script started" "$INFO_TAG" "ALL"
$wecho "Selected ports:${rawports}" "$INFO_TAG" "ALL"
steps=$(echo $arg_list | tr "\n" "," | tr " " ",")
$wecho "Selected steps:${steps%?}" "$INFO_TAG" "ALL"

# Run the expect scripts
if [[ $mode -eq 1 ]]; then      # Sequence mode
  while [ $fp -le $ep ]; do
    ( runner $fp )&
    # Retrieve the pid of the process in order to wait for it later
    pids[${i}]=$!
    fp=$(($fp+1))
  done
else
  k=0
  for i in ${PORTS[*]}; do    # List mode
    ( runner $i )&
    # Retrieve the pid of the process in order to wait for it later
    pids[${k}]=$!
    k=$(($k+1))
  done

fi

# Wait for all PIDs
for pid in ${pids[*]}; do
    wait $pid
done
end=`date +%s`

$wecho "MCH configuration script done ($((end-start))s)" "$INFO_TAG" "ALL"
