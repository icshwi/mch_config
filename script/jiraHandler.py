#!/usr/bin/env python3
#
#  Copyright (c) 2020        European Spallation Source ERIC
#
#  This program is free software: you can redistribute
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
#  author   : Ross Elliot
#  email    : ross.elliot@ess.eu
#
#  date     : Monday April 20 10:01:50 CEST 2020
#
#  version  : 0.0.1

"""
Script to handle calls to the Jira API from the MCH Configuration Tool
"""

__author__    = "Ross Elliot"
__email__     = "ross.elliot@ess.eu"
__copyright__ = "Copyright (c) 2020, European Spallation Source ERIC"
__license__   = "GPLv2"
__version__   = "0.1"
__status__    = "Development"

import sys
import argparse
import requests
import json
import os.path

class JIRAHandler:
    """ Jira API handler class

    This class provides the functionality to interface with the Jira REST API.

    The Jira python API is not used in this case, as it only supports basic
    (username and password in clear text), and oAuth authentication with the
    Jira server.
    """

    def __init__(self, cred, url, proj, tags):
        """Class constructor
        """

        # Assign arguments as class properties
        self.cred = cred
        self.url  = url + '/rest/api/latest'
        self.proj = proj
        self.tags = tags.split(',')

        # Set request headers
        self.headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "Authorization": 'Basic ' + cred
        }

    def verifyCredential(self):
        """ Perform a simple query to verify if the Jira credential is valid.

            Returns:
                res      (int)   : Success/Fail of attachment request
                                   -> 1 (success)
                                   -> 0 (fail)
        """

        if ((self.cred == "") | (self.cred == "FILL-ME!")):
            print("No Jira credential provided. Cannot authorise Jira API")
            ret = 0
        else:
            # Form URL
            credURL = self.url + "/search?jql=project=" + self.proj

            # Form request
            response = requests.request('GET', credURL, headers=self.headers)

            ret = 1
            # Parse response
            if (response.ok == False):
                print("Provided user credential is not authorised to access the Jira API")
                ret = 0

        return ret

    def findMCH(self, sn):
        """ Search the Jira project for an existing MCH entry

            Arguments:
                sn (str)    : Serial number of the MCH

            Returns:
                key (str)   : Identifier for the existing Jira ticket (on success)
                              Empty string (on failure)
        """

        # Form search URL
        searchURL = self.url + "/search?jql=labels=" + "&".join(self.tags) + "&project=" + self.proj + "&fields=key,summary"

        # Form search request
        response = requests.request('GET', searchURL, headers=self.headers)

        # Converts returned JSON to Python
        json_data = json.loads(response.text)

        # Loop through issues, and search for MCH serial number in the summary field
        key = ""
        for item in json_data["issues"]:
            if (item["fields"]["summary"].find(sn) > 0):
                key = item["key"]
                break

        return key

    def findTicket(self, key):
        """ Search for an existing Jira ticket by identifer

            Arguments:
                key (str)    : Jira ticket identifier

            Returns:
                found (bool) : True if found, False if not found
        """

        # Form search URL
        searchURL = self.url + "/search?jql=project=" + self.proj + "&fields=key"

        # Form search request
        response = requests.request('GET', searchURL, headers=self.headers)

        # Convert returned JSON to Python
        json_data = json.loads(response.text)

        found = False
        for item in json_data["issues"]:
            if (key == item["key"]):
                found = True
                break

        return found

    def addMCH(self, sn, parent, attachment, ttype):
        """ Method to create a new Jira ticket for the MCH

            Arguments:
                sn         (str) : Serial number of the MCH
                parent     (str) : Parent Jira ticket (optional)
                attachment (str) : Path to file to be attached to Jira ticket
                ttype      (str) : Ticket type (Story/Task)

            Returns:
                key    (str) : Identifier for the newly created Jira ticket (on success)
                               Error code (on failure)
        """

        # First, check if a Jira ticket already exists
        key = self.findMCH(sn)

        # Store return value
        ret = 0

        # Check if the MCH was already registered, by checking if a key was returned
        if (key != ""):
            print("Found SN %s in %s" % (sn, key))
            ret = 6
        else: # Not found - create new ticket
            print("Ticket not found for %s" % sn)

            # Check for existence of parent ticket
            if (parent != ""):
                if (self.findTicket(parent) == False):
                    print("Parent ticket (%s) does not exist" % parent)
                    return 2, key

            # Form add URL
            addURL = self.url + "/issue/"

            # Required data fields
            data = {"fields": { "project": { "key": self.proj },
                                "summary": "MCH " + sn + " test report",
                                "issuetype": { "name": ttype },
                                "labels": ["ICS", "ICS_Lab", "MCH", "MCHLog", "Test"]
                              }
                   }

            # Send POST request to Jira API, and get response
            response = requests.post(addURL, data=json.dumps(data), headers=self.headers)

            # Check if the response is good
            if (response.ok == True):
                # Get JSON return data
                respData = response.json()
                key = respData["key"] # Newly created Jira ticket identifier
                print("Ticket added for %s (%s)" % (sn, key))
            else: # Ticket creation failed
                return 1, key

        # Attach log archive
        if (attachment != ""):
            if(self.addAttachment(key, attachment) == 0):
                ret = 5

        # If a parent ticket is created, add the link to the new ticket
        if (parent != ""):
            if (self.addLink(key, parent) == 0):
                ret = 4

        # Return the Jira ticket identifier
        return ret, key

    def addAttachment(self, key, filename):
        """ Method to add a new attachment to an existing Jira ticket

            Arguments:
                key      (str)   : Identifier for the existing Jira ticket
                filename (str)   : Filename, including absolute path, to file to be attached

            Returns:
                res      (int)   : Success/Fail of attachment request
                                   -> 1 (success)
                                   -> 0 (fail)
        """

        # First, check if ticket exists
        found = self.findTicket(key)

        if (found == False):
            print("Ticket % does not exist" % key)
            res = 0
        elif (os.path.isfile(filename) != True):
            print("Provided filepath for attachment does not exist:\n\t%s" % attachment)
            res = 0
        else:
            # Form attachment URL
            attachURL = self.url + "/issue/" + key + "/attachments"

            # Get a copy of the common headers
            headers = self.headers.copy()
            # Append X-Atlassian-Token to headers
            headers.update({"X-Atlassian-Token": "no-check"})
            # Remove Content-Type from header, if it exists
            if "Content-Type" in headers:
                headers.pop("Content-Type")

            # Form files
            fileObj = open(filename, 'rb')
            files = {"file": fileObj}

            # Send post request to Jira API, and get response
            response = requests.post(attachURL, files=files, headers=headers)
            if (response.ok == True):
                print("File added to ticket: %s" % filename)
                res = 1
            else:
                print("Error uploading %s to ticket %s: %s" % (filename, key, response.text))
                res = response

        # Return
        return res

    def verifyAttachment(self, filename):
        """ Verify the filepath to the attachment exists in the system """

        res = 1
        if (filename != ""):
            # Verify that the provided path exists on the system
            if (os.path.isfile(filename) != True):
                print("Provided filepath for attachment does not exist:\n\t%s" % filename)
                res = 0

        return res

    def addLink(self, key, parent):
        """ Method to create a link between two JIRA issues

            Arguments:
                key    (str)    : Identifier for the child Jira ticket
                parent (str)    : Identifier for the parent Jira ticket

            Returns:
                res    (int)    : Success/Fail of Link request
                                  -> 1 (success)
                                  -> 0 (fail)
        """
        print("Linking %s with parent ticket (%s)" % (key, parent))

        # Form link URL
        linkURL = self.url + "/issueLink"

        # Required data for the link
        data = { "type": { "name": "Hierarchy" },
                 "inwardIssue": { "key": key },
                 "outwardIssue": { "key": parent }
               }

        response = requests.post(linkURL, data=json.dumps(data), headers=self.headers)
        if (response.ok == False):
            return 0

        return 1

if __name__ == '__main__':

    # Setup parser for input arguments
    parser = argparse.ArgumentParser(description='Helper script for the MCH config tool (bash) to handle access to the Jira REST API.')
    parser.add_argument('--credential', metavar='c', required=True, help='base64 encoded credential for HTTP Basic authorisation with the Jira server')
    parser.add_argument('--serial-number', metavar='s', required=True, help='Serial number of the MCH')
    parser.add_argument('--attachment', metavar='a', default='', help='Path to file to be attached to the Jira ticket')
    parser.add_argument('--project', metavar='p', default='ICSLAB', help='Jira project containing the MCH registration tickets (default: ICSLAB)')
    parser.add_argument('--url', metavar='u', default='https://jira.esss.lu.se',  help='Jira server URL (default: https://jira.esss.lu.se)')
    parser.add_argument('--parent-ticket', metavar='o', default='', help='Parent Jira ticket that the new MCH ticket should be a part of')
    parser.add_argument('--tags', metavar='t', default='MCHLog,ICS_Lab', help='Comma-separated list of Jira tags to assign to the ticket (default: MCHLog,ICS_Lab)')
    parser.add_argument('--type', metavar='y', choices=['Story', 'Task'], default='Story', help='Type of Jira ticket to create: ''Story'' or ''Task'' (default: Story)')
    args = parser.parse_args()

    # Assign internal variables parsed from input
    credential   = args.credential
    sn           = args.serial_number
    attachment   = args.attachment
    url          = args.url
    project      = args.project
    tags         = args.tags
    parentTicket = args.parent_ticket
    ticketType   = args.type

    ret = 0
    try:
        handler = JIRAHandler(credential, url, project, tags)
        res = handler.verifyCredential()
        if (res == 0):
            exit(7)
        res = handler.verifyAttachment(attachment)
        if (res == 0):
            exit(3)
        ret,key = handler.addMCH(sn, parentTicket, attachment, ticketType)
        if (key != ""):
            print("+-+-ISSUE=%s+-+-" % key)
    except Exception as e:
        print(e)
        exit(-2)

    exit(ret)
