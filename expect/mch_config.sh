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
#   date    : 20190308
#   version : 0.0.2

SCRIPT_INTERPRETER=expect

# Name of the source script (expect) to use for each step
FWUPDATE_SRC=fwupdate.exp
FWCHECK_SRC=fwcheck.exp
DHCPCFG_SRC=dhcp.exp
MCHCFG_SRC=mchconf.exp
CLK3U_SRC=clock_update_3u.exp
CLK9U_SRC=clock_update_9u.exp

# Current MCH firmware
CURRENT_VERSION=(2 20 4)

# Port numbers in the MOXA are 40XX
PORT_PREFIX=40

# Log
LOG_PREFIX="./log"
LOG_FILE=$LOG_PREFIX/"mch_config_"

# Flags for the different configuration steps: 1 -> enable the step
FW_UPDATE=1
DHCP_CFG=1
MCH_CFG=1
CLK_CFG_3U=0
CLK_CFG_9U=0

function help {
  cat << EOF
Usage: $(basename $0) MOXA_IP <port range> [options]
Arguments:
  MOXA_IP        -> IP address of the MOXA
  <port range>   -> Port range to apply the configuration.
                    It could be a list of ports or a range:
                    - Port range, from 1 to 16: 1-16
                    - Port list: 1,4,16
                    In order to run in only one port: 4, (don't forget ",")

Options:
  -h|--help      -> Prints this help
  -s|--steps     -> Specify wich steps to run:
                  1 -> FW update (default)
                  2 -> DHCP network configuration (default)
                  3 -> Standard MCH configuration (default)
                  4 -> Clock configuration for 3U crate
                  5 -> Clock configuration for 9U crate
                  By default, the script is executed with options: 1,2,3
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
# (1)  : Insuficient arguments
# (2)  : Failed to retrieve FW version string

function errecho {
  echo -e "\033[101;30m$1\033[0m"
}

function print_error {
  case $1 in
    1) errecho "Insuficient arguments passed to the script";;
    2) errecho "40$2::Couldn't retrieve a FW version, please manually check this port.";;
    *) errecho "Unrecognized error code";;
  esac
}

function fancyecho {
  echo -e "\033[107;34m$1\033[0m"
}

# Get which steps to run
function step_parser {
  # First diable all
  FW_UPDATE=0
  DHCP_CFG=0
  MCH_CFG=0
  CLK_CFG_3U=0
  CLK_CFG_9U=0
  arg_list=$(echo $1 | tr "," "\n")
  for arg in ${arg_list[*]}; do
    case "$arg" in
      1) FW_UPDATE=1;;
      2) DHCP_CFG=1;;
      3) MCH_CFG=1;;
      4) CLK_CFG_3U=1;;
      5) CLK_CFG_9U=1;;
      *) print_error "Unknow step number $arg"
    esac
  done
}

# Check FW of the MCH and update it if needed
# ___________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function update_fw {
  TEMPFILE=`mktemp`

  fancyecho "40$1::Checking FW version"
  run_script $FWCHECK_SRC $PORT_PREFIX$1 >  $TEMPFILE
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
    run_script $FWUPDATE_SRC $PORT_PREFIX$1 &
    # Usually it takes around 3 minutes
    sleep 240
    fancyecho "40$1::FW updated (New=${CURRENT_VERSION[*]})...."
  else
    fancyecho "40$1::FW up to date"
  fi
}

# Configure the MCH to accept an IP address from a DHCP server
# ____________________________________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function dhcp_conf {
  fancyecho "40$1::Setting up DCHP for the management port..."
  #run_script $DHCPCFG_SRC $PORT_PREFIX$1
  fancyecho "\n40$1::DCHP configuration done"
}

# Write the standard configuration
# ________________________________
# Arguments:
# $1 -> MOXA port index (1 to 16)

function mch_conf {
  fancyecho "40$1::Setting up MCH configuration..."
  #run_script $MCHCFG_SRC $PORT_PREFIX$1
  fancyecho "\n40$1::MCH configuration done"
}

function clk3u_conf {
  fancyecho "40$1::Setting up 3U clock configuration..."
  # Not tested yet
  #run_script $CLK3U_SRC $PORT_PREFIX$1
  fancyecho "\n40$1::3U clock configuration done"
}

function clk9u_conf {
  fancyecho "40$1::Setting up 9U clock configuration..."
  # Not tested yet
  #run_script $CLK9U_SRC $PORT_PREFIX$1
  fancyecho "\n40$1::9U clock configuration done"
}

# Check step flags and run the scripts on a specific port
function runner {
  if [[ $FW_UPDATE -eq 1 ]];    then update_fw  $1; fi
  if [[ $DHCP_CFG -eq 1 ]];     then dhcp_conf  $1; fi
  if [[ $MCH_CFG -eq 1 ]];      then mch_conf   $1; fi
  if [[ $CLK_CFG_3U -eq 1 ]];   then clk3u_conf $1; fi
  if [[ $CLK_CFG_9U -eq 1 ]];   then clk9u_conf $1; fi
}

# Start of the script magic
# _________________________
start=`date +%s`
mkdir -p $LOG_PREFIX
logfile="${LOG_FILE}`date "+%y%m%d_%H:%M:%S"`.log"
fancyecho "MCH configuration script init (`date "+%Y%m%d %H:%M:%S"`)" >> $logfile

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

# Argument parsing
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) help;;
    -s|--steps) step_parser $2;shift;;
    *) echo "Unknown arg: $1"; help;;
  esac
  shift
done

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
