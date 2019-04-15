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
#   version : 0.0.3

SCRIPT_INTERPRETER=expect

# Current MCH firmware
CURRENT_VERSION=(2 20 4)

# Port numbers in the MOXA are 40XX
PORT_PREFIX=40

# Flags for the different configuration steps: 1 -> enable the step
FW_UPDATE=1
DHCP_CFG=0
MCH_CFG=1
CLK_CFG=0
CFG_CHECK=0

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
  -l|--log       -> Log prefix. By default is "../log"
Examples:
Run the script to update FW only in the port 4010:
    mch_config.sh 10.0.5.173 10, -s 1
Run the script to configure DHCP in ports 10 to 14:
    mch_config.sh 10.0.5.173 10-14 --steps 2
Run the script with the default steps on ports 10,11 and 15:
    mch_config.sh 10.0.5.173 10,11,15

EOF
  exit 0
}

# Just another wrapper function
# Arguments:
# $2-> Port number (just last 2 digits).
# $1 -> Source script (Expect) to run
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


function errecho {
  echo -e "\033[101;30m$1\033[0m"
}

function print_error {
  case $1 in
    1) errecho "40$2::Generic error, check the logs";;
    2) errecho "40$2::Couldn't retrieve a FW version, please manually check this port.";;
    3) errecho "40$2::Insuficient arguments passed to the script";;
    4) errecho "40$2::MCH configuration is not properly setup";;
    *) errecho "Unrecognized error code";;
  esac
}

function fancyecho {
  echo -e "\033[107;34m$1\033[0m"
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
      *) print_error "Unknow step number $arg"
    esac
  done
}

# Check FW of the MCH and update it if needed
# ___________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function update_fw {

  local FW_TEMPFILE=$(mktemp -q --suffix=_fw)

  port=$(set_portN $1)
  
  fancyecho "40${port}::Checking FW version ${FW_TEMPFILE}"
  run_script $FWCHECK_SRC $port > $FW_TEMPFILE
  # Add all outputs to log file
  cat $FW_TEMPFILE
  echo ""
  fw_version=$(grep "MCH FW" $FW_TEMPFILE | egrep -oh "[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}")
  rm $FM_TEMPFILE

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
    fancyecho "40$port::Writing new FW (Old=$fw_version)...."
    run_script $FWUPDATE_SRC $port &
    # Usually it takes around 3 minutes
    sleep 240
    fancyecho "40$port::FW updated (New=${CURRENT_VERSION[*]})...."
  else
    fancyecho "40$port::FW up to date"
  fi
}

# Configure the MCH to accept an IP address from a DHCP server
# ____________________________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function dhcp_conf {
  local port=$(set_portN $1)
  fancyecho "40$port::Setting up DCHP for the management port..."
  run_script $DHCPCFG_SRC $port
  fancyecho "\n40$port::DCHP configuration done"
}

# Write the standard configuration
# ________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function mch_conf {
  local port=$(set_portN $1)
  fancyecho "40$port::Setting up MCH configuration..."
  run_script $MCHCFG_SRC $port
  fancyecho "\n40$port::MCH configuration done"
}

# Write the clock configuration
# _____________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)
function clk_conf {
  local port=$(set_portN $1)
  fancyecho "40$port::Setting up ${FORMFACTOR} clock configuration..."
  local CLK_SRC="CLK_SRC_$FORMFACTOR"
  run_script ${!CLK_SRC} $port
  fancyecho "\n40$port::${FORMFACTOR} clock configuration done"
}

# Check the written configuration
# _______________________________
#
#
function err_check {
  local port=$(set_portN $1)
  # This is really needed to avoid race conditions
  RUNNING_CFG=`mktemp`
  CMP1=`mktemp`
  CMP2=`mktemp`
  # Retrieve the IP address
  #run_script $CFGCHECK_SRC $1  > ${TEMPFILE}_2 
  #run_script $CFGCHECK_SRC $1  > $RUNNING_CFG;exit 0;
  # Now the run_script wrapper sends by default the output to /dev/null,
  # and here we really need that.
  $SCRIPT_INTERPRETER $CFGCHECK_SRC $MOXAIP $PORT_PREFIX$1 > $RUNNING_CFG
  # Delete output from expect script. Leave the configuration file.
  sed -i '/===  Text/,$!d' $RUNNING_CFG
  # Remove "===Text"
  sed -i '1,2d' $RUNNING_CFG
  # Last 2 lines need to be removed (promt and something else)
  sed -i "$(($(wc -l < ${RUNNING_CFG})-3)),\$d" $RUNNING_CFG
  #BUG: Sometimes there's still one blank line in the begining of the file.
  # I'm sorry but I don't know a clean way to do this:
  # awk '/^$/ && !f{f=1;next}1' ${TEMPFILE}_2 > ${TEMPFILE}
  local CFG_FILE="GOLDEN_CFG_${FORMFACTOR}"
  # In oder to avoid cumbersome missmatches, it's better to remove all 
  # commented and blank lines before the comparison.
  grep -o '^[^#]*' ${!CFG_FILE} > $CMP1
  grep -o '^[^#]*' $RUNNING_CFG > $CMP2
  diff --strip-trailing-cr --ignore-blank-lines $CMP1 $CMP2
  retvalue=$?
  #rm $TEMPFILE
  #rm ${TEMPFILE}_2
  if [[ $retvalue -ne 0 ]]; then exit 4; fi
  fancyecho "\n40$port::The configuration of the MCH is OK"
}

# Check step flags and run the scripts on a specific port
function runner {
  if [[ $DHCP_CFG -eq 1 ]];  then dhcp_conf  $1; fi
  if [[ $FW_UPDATE -eq 1 ]]; then update_fw  $1; fi
  if [[ $MCH_CFG -eq 1 ]];   then mch_conf   $1; fi
  if [[ $CLK_CFG -eq 1 ]];   then clk_conf   $1; fi
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
    -l|--log) LOG_PREFIX=$2;shift;;
    *) echo "Unknown arg: $1"; help;;
  esac
  shift
done

# We need to define properly the path to all the source files used by this
# script. We need to bear in mind that the script may be placed locally in
# the repository folder, or may be installed system wide.
if [ -z $SRC_PREFIX ]; then
  SRC_PREFIX=$(realpath $0);
  SRC_PREFIX=$(echo $SRC_PREFIX | sed "s|${0##*/}|../|g")
fi
var_definition

if [ -z $SRC_PREFIX ]; then LOG_PREFIX=../log; fi
LOG_FILE=$LOG_PREFIX/"mch_config_"

mkdir -p $LOG_PREFIX
logfile="${LOG_FILE}`date "+%y%m%d_%H:%M:%S"`.log"
fancyecho "MCH configuration script init (`date "+%Y%m%d %H:%M:%S"`)" >> $logfile

# Run the expect scripts
if [[ $mode -eq 1 ]]; then      # Sequence mode
  while [ $fp -le $ep ]; do
    runner $fp &>> $logfile &
    # Retrieve the pid of the process in order to wait for it later
    pids[${i}]=$!
    portn[${i}]=$fp

    fp=$(($fp+1))
  done
else
  k=0
  for i in ${PORTS[*]}; do    # List mode
    runner $i &>> $logfile &
    # Retrieve the pid of the process in order to wait for it later
    pids[${k}]=$!
    portn[${k}]=$i
    k=$(($k+1))
  done

fi

# Wait for all pids and print error code (if any)
i=0
for pid in ${pids[*]}; do
    wait $pid
    err=$?
    if [[ $err -ne 0 ]]; then
      print_error $err ${portn[$i]} >> $logfile
    fi
    i=$(($i+1))
done
end=`date +%s`

fancyecho "MCH configuration script done ($((end-start))s)" >> $logfile
