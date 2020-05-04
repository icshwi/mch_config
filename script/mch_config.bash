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
#             Jeong Han Lee
#             Ross Elliot
#   email   : torresfelipex1@gmail.com
#             jeonghan.lee@gmail.com
#             ross.elliot@ess.eu
#
#   date    : Monday, April 15 15:08:12 CEST 2019
#
#   version : 1.1.3

declare -gr SC_SCRIPT="$(realpath "$0")"
declare -gr SC_SCRIPTNAME=${0##*/}
declare -gr SC_TOP="${SC_SCRIPT%/*}"
declare -gr SC_LOGDATE="$(date +%y%m%d%H%M)"

# The following Global variable is used in run_script directly
#

# set -a
# . ${SC_TOP}/.tftp_ip.txt
# set +a

# Detect if running in a VM of the INFRA group (use Python Venv)
if [[ -d /opt/conda/envs/csentry/bin ]]; then
  source /opt/conda/etc/profile.d/conda.sh
  conda activate csentry
fi


# File with some function definitions to interface with Jira
source ${SC_TOP}/jirahandler.bash

# Flag to enable some extra functionalities to add content to Jira
ENABLE_JIRA=0
PARENT_TICKET=""    # Default Jira parent ticket (none)
TICKET_TYPE="Story" # Default Jira ticket type
# base64-encoded Jira credential token
JIRA_CREDENTIAL="FILL-ME!"

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


## CSentry related configuration
#  -----------------------------
# Flag to enable the register of the MCH(s) in CSentry before running the
# tests. A timeout is set at the end of this step to let the DHCP server get
# updated.
CSEntry=0
# CSEntry url
CSentry_url="https://csentry-test.esss.lu.se/"
# CSEntry Network
NETWORK="CSLab-GeneralLab"
GROUP=""
# Flag to control the log system in the application
# Valid options:
# -> "WEB" : All messages will contain extra information for the web interface
# -> "USER" : Only human readable information in the output messages
# -> "" : Raw format

# Flag that indicates when a MOXA hub it's used for the connection to the MCH
MOXA=1

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
                  0 -> Register MCH(s) in CSEntry
                  1 -> DHCP network configuration (default)
                  2 -> FW update (default)
                  3 -> Standard MCH configuration (default)
                  4 -> Standard MCH configuration (with check)
                  5 -> Clock configuration
                  6 -> Clock configuration (with check)
                  7 -> Check all configurations (general and clock)
                  By default, the script is executed with options: 1,2,3,5
  -p|--prefix    -> Source prefix for the tool. By default is "../".
  -l|--log       -> Enable a human readable log
  -w|--web       -> Enable web log (interface with the WEBUI)
  -j|--jira      -> Enable to upload the results to Jira.
  -t|--ticket    -> Parent Jira ticket to link the new Jira ticket to.
                    Link will be of type "part of".
  -y|--type      -> Type of Jira ticket to create (Story or Task).
  -x|--nomoxa    -> Enable access via telnet (when not using a MOXA Hub)
  -n|--network   -> Specify the Network that the MCH will be registered on in
                    CSEntry. Default is 'CSLab-GeneralLab'.
  -g|--group     -> Specify the Ansible group(s) that the MCH will be registered
                    to in CSEntry. Multiple groups can be specified as a list
                    separated by the '&' character, i.e. Group1&Group2.
                    Default is empty.
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
    local src_script="$1";
    local portN="$2";
    # This extra parameter allows sending a command directly to expect. Useful
    # whenever you need to get the output from a simple command.
    local custom="$3"
    local lport="$PORT_PREFIX$portN"

    # Set default telnet port when not using a MOXA
    if [[ $MOXA -eq 0 ]]; then
      lport="23"
    fi
    $SCRIPT_INTERPRETER "$src_script" "$MOXAIP" $lport "$SC_LOGDATE" "$custom"
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
  case "$1" in
    1) $wecho "Generic error, check the logs" "$2" "$3";;
    2) $wecho "Couldn't retrieve a FW version, please manually check this port." "$2" "$3";;
    3) $wecho "Insuficient arguments passed to the script" "$2" "$3";;
    4) $wecho "MCH configuration is not properly setup" "$2" "$3";;
    5) $wecho "Wrong step argument" "$2" "$3";;
    *) $wecho "Unrecognized error code" "$2" "$3";;
  esac
}

# echo wrapper to include extra information for the web interface
# _______________________________________________________________
# Arguments:
# 1 -> message content
# 2 -> message type (see description in the beginning of the source code)
# 3 -> message destination (see description in the beginning)
function webecho {
  local msg="$1"
  local type="$2"
  local dest="$3"
  echo "$INIT_TAG$type::@$3::$msg$END_TAG"
  if [[ $ENABLE_JIRA -eq 1 ]]; then
    echo "$INIT_TAG$type::@$3::$msg$END_TAG" >> $JIRA_LOG
  fi
}

# echo wrapper to beautify a little bit the output messages
# _________________________________________________________
# 1 -> message content
# 2 -> type: "err" or "inf" or "dbg"
# 3 -> port number
function userecho {
  local msg="$1"
  local type="$2"
  local port="@$3"

  if [[ $port = "@ALL" ]]; then port="";fi
  if [[ $type = "inf" ]]; then format="107;34";
  elif [[ $type = "dbg" ]]; then format="94"
  else format="101;30"; fi

  echo -e "\033[${format}m$msg $port\033[0m"

  if [[ $ENABLE_JIRA -eq 1 ]]; then
    echo "$INIT_TAG$type::@$3::$msg$END_TAG" >> $JIRA_LOG
  fi
}

function set_portN {

    local portN="$1"; shift;

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
  arg_list=$(echo "$1" | tr "," "\n")
  for arg in ${arg_list[*]}; do
      case "$arg" in
      0) CSENTRY=1;;
      1) DHCP_CFG=1;;
      2) FW_UPDATE=1;;
      3) MCH_CFG=1;;
      4) MCH_CFG=2;;
      5) CLK_CFG=1;;
      6) CLK_CFG=2;;
      7) CFG_CHECK=1;;
      *) print_error 5 "err" "@ALL"
    esac
  done
}

# Register the MAC of every MCH in the run in CSEntry.
# ____________________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 32)
# Returns:
# 0 -> The MCH was succesfully registered
# 1 -> The MCH was previously registered
function register_mch {
  port=$(set_portN "$1")
  $wecho "Init MCH register @ CSEntry" "$INFO_TAG" "40$port"
  $wecho "API url=$CSentry_url" "$DBG_TAG" "40$port"

  # MAC address & s/n are needed to registry a new Host in CSEntry
  # Use the generic expect script to retrieve the info from the command
  # "bi".
  local CFG_TEMPFILE=$(mktemp -q --suffix=_bi)
  $wecho "MCH board info tempfile: $CFG_TEMPFILE" "$DBG_TAG" "40$port"
  run_script $CFGCHECK_SRC $port "bi" > $CFG_TEMPFILE
  local filelines=$(wc -l $CFG_TEMPFILE | cut -d " " -f1)
  if [[ $filelines -le 3 ]]; then
    $wecho "Error in MCH clock configuration check." "$ERR_TAG" "40$port"
    exit 1
  fi
  sn=$(grep --text -Po 'Board Identifier.*:.*\K(\d{6}-\d{4})' $CFG_TEMPFILE)
  mac=$(grep --text -Po 'IEEE Address.*:.*\K(([0-9a-f]-?){12})' $CFG_TEMPFILE | tr '-' ':')
  if [[ ! $sn = ""  && ! $mac = "" ]]; then
    $wecho "The MCH is identified by s/n=$sn and MAC=$mac" "$DBG_TAG" "40$port"
    $wecho "The MCH will be registered on the '$NETWORK' network." "$DBG_TAG" "40$port"
  else
    $wecho "Error determining MCH serial number and MAC. Check that the MCH is powered on and - if using a MOXA - connected to the correct port." "$ERR_TAG" "40$port"
    exit 1
  fi
  local temp_log=$(mktemp -q --suffix=_pylog)
  if [[ ! $GROUP = "" ]]; then
    $wecho "The Ansible group(s) '$GROUP' will be assigned to the MCH in CSEntry." "$DBG_TAG" "40$port"
    python3 $CSEntry_Py_HDLR --mac-address="$mac" --serial-number="$sn" --network="$NETWORK" --group="${GROUP}" --url="$CSentry_url" > $temp_log
  else
    python3 $CSEntry_Py_HDLR --mac-address="$mac" --serial-number="$sn" --network="$NETWORK" --url="$CSentry_url" > $temp_log
  fi
  local ret=$?

  # Send the output messages from the Python script to the debug logger
  while IFS= read -r line
  do
    $wecho "$line" "$DBG_TAG" "40$port"
  done < "$temp_log"

  # The error code from the python script may be a negative number
  if [[ $ret -gt 127 ]]; then
    $wecho "Error in the MCH registry." "$ERR_TAG" "40$port"
    exit 1
  elif [[ $ret -eq 0 ]]; then
    $wecho "The MCH has been succesfully registered @ CSEntry." "$INFO_TAG" "40$port"
    $wecho "DHCP server takes ~3 minutes to update. Sleeping for 180 s..." "$INFO_TAG" "40$port"
    sleep 180
  elif [[ $ret -eq 1 ]]; then
    $wecho "The MCH was already registered @ CSEntry." "$INFO_TAG" "40$port"
    $wecho "End MCH register @ CSEntry" "$INFO_TAG" "40$port"
    return 1
  elif [[ $ret -eq 2 ]]; then
    $wecho "The provided network string ("$NETWORK") is not valid." "$INFO_TAG" "40$port"
    return 2
  elif [[ $ret -eq 3 ]]; then
    $wecho "The provided Ansible group ("$GROUP") is not valid." "$INFO_TAG" "40$port"
    return 3
  fi

  $wecho "End MCH register @ CSEntry" "$INFO_TAG" "40$port"
  return 0
}

# Check FW version and return if the current version matches the expected one
# ___________________________________________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 32)
# Returns
# 0 -> if there's no need to update
# 1 -> if the current version is older than the one expected
function check_fw {
  port=$(set_portN "$1")
  $wecho "Init FW version checking" "$INFO_TAG" "40$port"

  local FW_TEMPFILE=$(mktemp -q --suffix=_fw)
  $wecho "FW tempfile: $FW_TEMPFILE" "$DBG_TAG" "40$port"
  run_script $FWCHECK_SRC $port > $FW_TEMPFILE
  # No error is raisen in that kind of calls. We cannot trust in $?. Then we can
  # check for the number of lines of the temporal file. When no connection is
  # stablish, this file contains only 3 lines.
  local filelines=$(wc -l $FW_TEMPFILE | cut -d " " -f1)
  if [[ $filelines -le 3 ]]; then
    $wecho "Error in FW check." "$ERR_TAG" "40$port"
    exit 1
  fi

  fw_version=$(grep "MCH FW" $FW_TEMPFILE | egrep -oh "[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}")
  $wecho "Current FW version:$fw_version" "$DBG_TAG" "40$port"
  local current_ver=$(echo ${CURRENT_VERSION[*]} | tr ' ' '.')
  $wecho "Expected FW version:$current_ver" "$DBG_TAG" "40$port"
  rm -f $FW_TEMPFILE

  if [ "x$fw_version" == "x" ]; then
    print_error 2 "err" "40$port"
    exit 2
  fi

  UPDATE=0
  local x0=$(echo ${fw_version} | cut -d"." -f1)
  local x1=$(echo ${fw_version} | cut -d"." -f2)
  local x2=$(echo ${fw_version} | cut -d"." -f3)

  for i in $(seq 0 2); do
    local VAR="x$i"
    if [[ ${!VAR} -lt ${CURRENT_VERSION[$i]} ]]; then
      UPDATE=1; break;
    elif [[ ${!VAR} -gt ${CURRENT_VERSION[$i]} ]]; then
      UPDATE=0; break;
    fi
  done

  $wecho "End FW version checking (RET=$UPDATE)" "$INFO_TAG" "40$port"
  return $UPDATE
}

# Check FW of the MCH and update it if needed
# ___________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 32)

function update_fw {
  port=$(set_portN "$1")
  $wecho "Init FW version update" "$INFO_TAG" "40$port"
  check_fw "$1"
  UPDATE=$?

  if [[ $UPDATE -eq 1 ]]; then
    $wecho "Updating FW version" "$INFO_TAG" "40$port"
    run_script $FWUPDATE_SRC $port &>> /dev/null
    if [[ $? -ne 0 ]]; then
      $wecho "Error in FW update." "$ERR_TAG" "40$port"
      exit 1
    fi
    # Usually it takes around 3 minutes
    $wecho "FW updated, waiting for reboot... ($UPDATE_SLEEP s)" "$INFO_TAG" "40$port"
    sleep $UPDATE_SLEEP
    $wecho "Updated FW version" "$INFO_TAG" "40$port"
    $wecho "Checking FW version after update" "$INFO_TAG" "40$port"
    check_fw "$1"
    UPDATED=$?
    if [[ $UPDATED -eq 1 ]]; then
      $wecho "FW is not properly updated. Ending process..." "ERR_TAG" "40$port"
      exit 5
    else
      $wecho "FW succesfully updated" "$INFO_TAG" "40$port"
    fi
  else
    $wecho "FW version up to date" "$INFO_TAG" "40$port"
  fi

  $wecho "End FW version update" "$INFO_TAG" "40$port"
}

# Configure the MCH to accept an IP address from a DHCP server
# ____________________________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function dhcp_conf {
  local port=$(set_portN "$1")
  $wecho "Init DCHP configuration" "$INFO_TAG" "40$port"
  run_script $DHCPCFG_SRC $port &>> /dev/null
  if [[ $? -ne 0 ]]; then
    $wecho "Error in the DHCP configuration." "$ERR_TAG" "40$port"
    exit 1
  fi

  $wecho "End DCHP configuration" "$INFO_TAG" "40$port"
  sleep $SLEEP
}

# Write the standard configuration
# ________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function mch_conf {
  local port=$(set_portN "$1")
  $wecho "Init MCH general configuration" "$INFO_TAG" "40$port"
  run_script $MCHCFG_SRC $port &>> /dev/null
  if [[ $? -ne 0 ]]; then
    $wecho "Error in the MCH general configuration." "$ERR_TAG" "40$port"
    exit 1
  fi

  $wecho "End MCH general configuration" "$INFO_TAG" "40$port"
  sleep $SLEEP
}

# Write the clock configuration
# _____________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)
function clk_conf {
  local port=$(set_portN "$1")
  $wecho "Init MCH clock configuration" "$INFO_TAG" "40$port"
  local CLK_SRC="CLK_SRC_$FORMFACTOR"
  run_script ${!CLK_SRC} $port &>> /dev/null
  if [[ $? -ne 0 ]]; then
    $wecho "Error in MCH clock configuration." "$ERR_TAG" "40$port"
    exit 1
  fi
  $wecho "End MCH clock configuration" "$INFO_TAG" "40$port"
  sleep $SLEEP
}

# Check the general configuration
# _______________________________
# Arguments:
# $1 -> MOXA port index (1 to 32)
function cfg_check {
  local port=$(set_portN "$1")
  local CFG_TEMPFILE=$(mktemp -q --suffix=_cfg)
  local CFG_TEMPFILE2=$(mktemp -q --suffix=_cfg)
  local DIFF_TEMPFILE=$(mktemp -q --suffix=_diff)
  $wecho "Init MCH configuration check" "$INFO_TAG" "40$port"
  $wecho "CFG tempfile: $CFG_TEMPFILE" "$DBG_TAG" "40$port"
  $wecho "CFG tempfile2: $CFG_TEMPFILE2" "$DBG_TAG" "40$port"
  run_script $CFGCHECK_SRC $port "mch" > $CFG_TEMPFILE
  local filelines=$(wc -l $CFG_TEMPFILE | cut -d " " -f1)
  if [[ $filelines -le 3 ]]; then
    $wecho "Error in MCH configuration check." "$ERR_TAG" "40$port"
    exit 1
  fi
  # Remove the useless head of the file
  sed "1,8d" -i $CFG_TEMPFILE
  # Remove last lines from configuration (hostname and DHCP)
  tac $CFG_TEMPFILE | sed "1,4d" | tac > $CFG_TEMPFILE2
  diff --strip-trailing-cr --ignore-blank-lines $GENERIC_CFG $CFG_TEMPFILE2 > $DIFF_TEMPFILE
  if [[ $? = 0 ]]; then
    $wecho "Configuration file is identical" "$INFO_TAG" "40$port"
    rm $CFG_TEMPFILE
    rm $CFG_TEMPFILE2
    rm $DIFF_TEMPFILE
  else
    $wecho "General configuration file differs" "$ERR_TAG" "40$port"
    $wecho "See $DIFF_TEMPFILE" "$DBG_TAG" "40$port"
  fi

  $wecho "End MCH configuration check" "$INFO_TAG" "40$port"
}

# Check the clock configuration
# _____________________________
# Arguments:
# $1 -> MOXA port index (1 to 32)
function clk_check {
  local port=$(set_portN "$1")
  local CFG_TEMPFILE=$(mktemp -q --suffix=_cfg)
  local DIFF_TEMPFILE=$(mktemp -q --suffix=_diff)
  $wecho "Init MCH clock check" "$INFO_TAG" "40$port"
  $wecho "CLK CFG tempfile: $CFG_TEMPFILE" "$DBG_TAG" "40$port"
  run_script $CFGCHECK_SRC $port "ni" > $CFG_TEMPFILE
  local filelines=$(wc -l $CFG_TEMPFILE | cut -d " " -f1)
  if [[ $filelines -le 3 ]]; then
    $wecho "Error in MCH clock configuration check." "$ERR_TAG" "40$port"
    exit 1
  fi
  ip=$(grep -Po 'ip address.*:.\K(\d{1,3}\.?){1,4}' $CFG_TEMPFILE)
  $wecho "Retrieving the MCH configuration file ($ip)..." "$DBG_TAG" "40$port"
  ping -c 1 $ip &>> /dev/null
  if [[ $? != 0 ]]; then
    $wecho "Can't access to the MCH webserver" "$ERR_TAG" "40$port"
    return 1
  fi
  curl -u root:nat "http://$ip/goform/web_cfg_backup_show_menu" &>> /dev/null
  curl -u root:nat -o $CFG_TEMPFILE "http://$ip/nat_mch_startup_cfg.txt" &>> /dev/null
  local GOLDEN_CFG="GOLDEN_CFG_$FORMFACTOR"
  diff --strip-trailing-cr --ignore-blank-lines ${!GOLDEN_CFG} $CFG_TEMPFILE > $DIFF_TEMPFILE
  if [[ $? = 0 ]]; then
    $wecho "Clock configuration file is identical" "$INFO_TAG" "40$port"
    rm $CFG_TEMPFILE
    rm $DIFF_TEMPFILE
  else
    $wecho "Clock configuration file differs" "$ERR_TAG" "40$port"
    $wecho "See $DIFF_TEMPFILE" "$DBG_TAG" "40$port"
  fi

  $wecho "End MCH clock check" "$INFO_TAG" "40$port"
}

# Check step flags and run the scripts on a specific port
function runner {
  if [[ $CSENTRY   -eq 1 ]];  then register_mch "$1"; fi
  if [[ $DHCP_CFG  -eq 1 ]];  then dhcp_conf  "$1"; fi
  if [[ $FW_UPDATE -eq 1 ]];  then update_fw  "$1"; fi
  if [[ $MCH_CFG   -gt 0 ]];  then
    mch_conf "$1"
    if [[ $MCH_CFG -gt 1 ]]; then cfg_check "$1"; fi
  fi
  if [[ $CLK_CFG   -gt 0 ]]; then
    clk_conf "$1"
    if [[ $CLK_CFG -gt 1 ]]; then clk_check "$1"; fi
  fi
  if [[ $CFG_CHECK -eq 1 ]];  then cfg_check "$1"; clk_check  "$1"; fi
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
  CFGCHECK_SRC=$EXPECT_PREFIX/generic.exp

  #declare -A GOLDEN_CFG
  GOLDEN_CFG_3U=$CFG_PREFIX/nat_mch_fw2.20.4_3u_cfg.txt
  GOLDEN_CFG_9U=$CFG_PREFIX/nat_mch_fw2.20.4_9u_cfg.txt
  GOLDEN_CFG_5U=$CFG_PREFIX/nat_mch_fw2.20.4_mini_cfg.txt
  GENERIC_CFG=$CFG_PREFIX/GOLDEN_cfg.txt

  # Script to set DHCP configuration
  DHCPCFG_SRC=$EXPECT_PREFIX/dhcp.exp

  # Scripts that load the clock configuration
  #declare -A CLK_SRC
  CLK_SRC_3U=$EXPECT_PREFIX/clock_update_3u.exp
  CLK_SRC_5U=$EXPECT_PREFIX/clock_update_mini.exp
  CLK_SRC_9U=$EXPECT_PREFIX/clock_update_9u.exp

  # Python Helper scripts
  # By now the only python script will be located in the same folder as the
  # rest of the scripts
  CSEntry_Py_HDLR=${SRC_PREFIX}/script/csentryHandler.py
  Jira_Py_HDLR=${SRC_PREFIX}/script/jiraHandler.py

  INIT_TAG="^"
  END_TAG=";;"
  INFO_TAG="inf"
  DBG_TAG="dbg"
  ERR_TAG="err"

  wecho=echo
  if [[ $LOG = "USER" ]]; then wecho=userecho;
  elif [[ $LOG = "WEB" ]]; then wecho=webecho; fi

  if [[ $ENABLE_JIRA -eq 1 ]]; then
    JIRA_LOG=$(mktemp -q --suffix=_jira)
    if [[ $wecho == "echo" ]]; then
      echo "Warning!!: Chose -w or -l to build the log which will be uploaded to Jira."
    fi
  fi
}

# Start of the script magic
# _________________________
start=$(date +%s)

if [[ $# -lt 1 ]]; then brief_help; exit 1;
elif [[ $1 = "--help" ]] || [[ $1 = "-h" ]]; then help; exit 1;
elif [[ $# -lt 3 ]]; then print_error 1; exit 1;
fi

MOXAIP="$1"
PORTS="$2"
rawports="$2"
FORMFACTOR="$3"

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
    -s|--steps) step_parser "$2";shift;;
    -p|--prefix) SRC_PREFIX="$2";shift;;
    -l|--log) LOG="USER";;
    -w|--web) LOG="WEB";;
    -j|--jira) ENABLE_JIRA=1;;
    -t|--ticket) PARENT_TICKET="$2";shift;;
    -y|--type) TICKET_TYPE="$2";shift;;
    -x|--nomoxa) MOXA=0;;
    -n|--network) NETWORK="$2";shift;;
    -g|--group) GROUP="$2";shift;;
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
end=$(date +%s)

$wecho "MCH configuration script done ($((end-start))s)" "$INFO_TAG" "ALL"

if [[ $ENABLE_JIRA -eq 0 ]]; then exit 0;fi

# ENABLE_JIRA allows to upload the results from the script to Jira.
# Every registered MCH will have an associated "Story" ticket in Jira. In that
# ticket, we'll store a compress file from every registered run.
# That compressed file contains a file with the log output and every inidividual
# expect log file as well.

$wecho "Uploading the results to Jira..." "$INFO_TAG" "ALL"

if [[ $mode -eq 1 ]]; then
  fp=$(echo $PORTS | cut -d"-" -f1)
  ports=$(seq $fp $ep)
else
  ports=${PORTS[*]}
fi

for i in ${PORTS[*]}; do
  port=$(set_portN $i)
  CFG_TEMPFILE=$(mktemp -q)

  # First get the Board identifier and check if this board has already
  # an associated ticket
  run_script $CFGCHECK_SRC $port "bi" > $CFG_TEMPFILE
  filelines=$(wc -l $CFG_TEMPFILE | cut -d " " -f1)
  if [[ $filelines -le 3 ]]; then
    $wecho "Error while retrieving the MCH s/n" "$ERR_TAG" "40$port"
    exit 1
  fi
  sn=$(grep -aoP -m 1 "Board Identifier:.?\K\d{6}\-\d{4}" $CFG_TEMPFILE)
  if [[ "x$sn" = "x" ]]; then
    $wecho "Error while retrieving the MCH s/n" "$ERR_TAG" "40$port"
    exit 1
  fi

  # Second step: take the files for that board
  path="/tmp/mch_${sn}_testreport_$SC_LOGDATE"
  mkdir -p $path
  grep "@40$port" $JIRA_LOG > "$path/logfile.txt"
  cp /tmp/mch_testreports/MCH_*_40${port}_$SC_LOGDATE.log $path
  zip -r $path $path >> /dev/null
  $wecho "Created zip file of test reports: ${path}.zip" "$DBG_TAG" "$PORT_PREFIX""$port"

  # Call Python Jira handler to add MCH ticket.
  #
  # It will perform the following steps:
  #   1. Check if Jira ticket already exists for the current MCH
  #   2. Check if the optional Parent ticket is valid
  #   3. Create a new Jira ticket for the current MCH (and link it
  #      to the parent ticket, if provided
  #   4. Attach the compressed log archive to the new ticket
  #
  # Using the following default values:
  #   * --url     = https://jira.esss.lu.se
  #   * --project = ICSLAB
  #   * --tags    = MCHLog,ICS_Lab
  temp_jira_log=$(mktemp -q --suffix=__py_jiralog)
  python3 "$Jira_Py_HDLR" --credential="$JIRA_CREDENTIAL" --serial-number="$sn" --parent-ticket="$PARENT_TICKET" --attachment="${path}.zip" --type="$TICKET_TYPE" 2>&1 >$temp_jira_log

  # Get exit code
  ret=$?
  ISSUE=""
  # Send the output messages from the Python script to the debug logger
  while IFS= read -r line
  do
    if [[ "$line" == *"+-+-ISSUE"* ]]; then
        ISSUE=$(echo $line | sed -e 's/+-+-ISSUE=\(.*\)+-+-/\1/')
    else
        $wecho "$line" "$DBG_TAG" "$PORT_PREFIX""$port"
    fi
  done < "$temp_jira_log"

  if [[ $ret -gt 127 ]]; then
    $wecho "Error uploading results to Jira." "$ERR_TAG" "$PORT_PREFIX""$port"
  elif [[ $ret -eq 0 ]]; then
    $wecho "Ticket added for "$sn" ("$ISSUE")" "$INFO_TAG" "$PORT_PREFIX""$port"
    if [[ "$PARENT_TICKET" != "" ]]; then
      $wecho "New ticket linked to parent ticket ("$PARENT_TICKET")" "$INFO_TAG" "$PORT_PREFIX""$port"
    fi
  elif [[ $ret -eq 1 ]]; then
    $wecho "Ticket creation via the Jira API failed." "$ERR_TAG" "$PORT_PREFIX""$port"
  elif [[ $ret -eq 2 ]]; then
    $wecho "Provided parent Jira ticket ($PARENT_TICKET) does not exist." "$ERR_TAG" "$PORT_PREFIX""$port"
  elif [[ $ret -eq 3 ]]; then
    $wecho "The attachment (${path}.zip) does not exist." "$ERR_TAG" "$PORT_PREFIX""$port"
  elif [[ $ret -eq 4 ]]; then
    $wecho "Linking ticket ($ISSUE) to the parent ticket ($PARENT_TICKET) failed." "$ERR_TAG" "$PORT_PREFIX""$port"
  elif [[ $ret -eq 5 ]]; then
    $wecho "Uploading attachment to ticket ($ISSUE) failed." "$ERR_TAG" "$PORT_PREFIX""$port"
  elif [[ $ret -eq 6 ]]; then
    $wecho "Serial number "$sn" found in existing Jira ticket - ("$ISSUE")" "$INFO_TAG" "$PORT_PREFIX""$port"
  fi

done
