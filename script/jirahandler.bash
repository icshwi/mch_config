#!/usr/bin/env bash
#
#  This script is made to be sourced
#  It contains a set of functions to upload the results from the MCH
#  configuration process to Jira.
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
#
#   date    : Monday, May 13 11:37:12 CEST 2019
#
#   version : 0.1

if [ -z $JIRA_PREFIX ]; then
  JIRA_PREFIX=$(realpath $0);
  JIRA_PREFIX=$(echo $JIRA_PREFIX | sed "s|${0##*/}||g")
fi

# To build the credential string:
# echo -n "user:password" | openssl base64
# This string is empty in the repository!!
declare -gr CREDENTIAL="FILL ME"
declare -gr CREDENTIAL_HEADER="Authorization: Basic $CREDENTIAL"

declare -gr JIRA_API="https://jira.esss.lu.se/rest/api/latest"

# Label that groups all the Jira issues
declare -gr MCH_TAG="MCHLog&ICS_Lab"

# JSON template for new issues
declare -gr ISSUE_TEMPLATE="${JIRA_PREFIX}newissue.json"

# find_MCH: Looks fro the MCH serial number into the Jira DB
# summary:
#   This function sends a GET to the Jira API to retrieve all the issues with
#   tagged with $MCH_TAG. Then it looks for the serial number of the current
#   MCH.
# arguments:
# $1 -> MCH serial number. Format: "XXYYZZ-ABCD"
# returns:
# - Exit codes: 0 if found, 1 otherwise
# - Set variable ISSUE (only last 4 digits) with the number of the issue
#   containing the MCH s/n.
function find_MCH {
  local mch_sn=$1
  local file="/tmp/jiratempfile"
  issues=$(curl --silent \
                -H "$CREDENTIAL_HEADER" \
                -X GET -H 'Content-Type: application/json' \
                "$JIRA_API/search?jql=labels=$MCH_TAG&project=ICSLAB&fields=key,summary")
  # Remember to change the regex when the issue number > 9999
  found=$(echo $issues | sed 's|"||g' | grep -oP "key:ICSLAB-\d{1,4},fields:\{.*?\}")
  issues=$(echo $found | sed 's|fields:||g')
  lineissues=$(echo $issues | sed 's|{||g')
  echo $lineissues | tr "}" "\n" > $file
  # Remove leading white spaces
  sed -e 's/^[ \t]*//' -i $file
  # Remove blank lines
  sed '/^$/d' -i $file
  grep $mch_sn $file >> /dev/null
  retcode=$?
  if [[ $retcode -eq 0 ]]; then
    export ISSUE=$(grep $mch_sn $file | cut -d',' -f1 | cut -d':' -f2)
  fi
  return $retcode
}

# add_MCH: add a new ticket in Jira for the MCH
# summary:
#   This function creates a new ticket in Jira with the format stored in
#   'newissue.json'.
#
# arguments:
# $1 -> MCH serial number. Format: "XXYYZZ-ABCD"
# returns:
# The issue number (and exports the variable ISSUE)
function add_MCH {
  local file="/tmp/jiratempfile"
  local mch_sn=$1

  sed "s/%sn%/$mch_sn/g" $ISSUE_TEMPLATE > tempjson
  response=$(curl --silent \
       -H "$CREDENTIAL_HEADER" \
       -X POST \
       --data @tempjson \
       -H 'Content-Type: application/json' \
       "$JIRA_API/issue/")
   # Remember to change the regex when the issue number > 9999
   export ISSUE=$(echo $response | grep -oP "key.?:.?\KICSLAB-\d{1,4}")
   rm tempjson

   return $ISSUE
}

# add_Attachment: Add a new attachment to a Jira ticket
# summary:
#   This function add a new attachment file to an existing Jira ticket.
#
# arguments:
# $1 -> Ticket number (only numeric part)
# $2 -> File to attach
# returns:
# 1 -> on success
# 0 -> otherwise
function add_Attachment {
  local file="/tmp/jiratempfile"
  local mch_sn=$1
  local log=$2

  response=$(curl --silent \
        -H "$CREDENTIAL_HEADER" \
        -X POST \
        -H "X-Atlassian-Token: no-check" \
        -F "file=@$log" \
        $JIRA_API/issue/$mch_sn/attachments)
  echo $response | grep "errorMessages" >> /dev/null
  return $?
}
