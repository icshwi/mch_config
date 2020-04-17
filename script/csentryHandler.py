#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Script to handle NAT MCH board in CSEntry

This is a helper script for the MHC config tool (Bash) to handle the access
to the CSEntry API.
The main purpose of this module is to access the CSEntry data base to check if
a given MAC address is already registered or not. If not, the script will
create a new host device and it will associate the MAC address to it.

The script is intended to be called as an standalone module from the main
tool. The script will receive two positional arguments: the serial number of the
MCH and the MAC address.
The returned value will be 0 if either there's an existing MCH with that MAC
address or a new one was created. And a negative value if any error ocurred.
"""

__author__    = "Felipe Torres González"
__email__     = "felipe.torresgonzalez@ess.eu"
__author__    = "Ross Elliot"
__email__     = "ross.elliot@ess.eu"
__copyright__ = "Copyright 2020, European Spallation Source"
__license__   = "GPL"
__version__   = "1.2"
__status__    = "Development"

import sys
import argparse

from csentry import CSEntry

class CSEntryHandler:
    """CSEntry handler

    This class provides the main functionality to interface with CSEntry. It
    also provides methods to perform the required actions by the MCH tool:
    - Check if a MAC address already exists in the DB
    - Create a new host device and associate the MAC address and hostname
      based on a specific MCH.
    """

    def __init__(self, token, url):
        """Class constructor

        Arguments:

        token (str): A valid development token for CSEntry
        url (str): The url for the CSEntry API
        """
        self._con = CSEntry(token=token, url=url)

    def searchHOST(self, mac):
        """Search in the CSEntry database for a device with the specified MAC

        Arguments:

        mac (str): a string containing the MAC address. The expected format
                   is AA:BB:CC:DD:EE:FF. It is indiferent to use capital
                   letters or not.
        Returns:

        A tuple. Empty if the host was not found. Containing the hostname and
        the IP address, if found.
        """
        # hosts is a dict containing all the hosts registered in CSEntry
        hosts = self._con.search_hosts()

        # Hosts with no interfaces can be discarded. Then search for the MAC.
        for host in hosts:
            if "interfaces" not in host:
                continue
            # A host may contain many interfaces
            for interface in host['interfaces']:
                if "mac" not in interface:
                    continue
                else:
                    if mac.lower() == interface['mac']:
                        return (interface['host'],interface['ip'])
        return tuple()

    def registerNewHost(self, mac, sn, net, grp):
        """Register a new host in CSEntry

        A new host device will be registered with the given data.

        Hostname will be mch-<serial number>.cslab.esss.lu.se
        Device type will be MTCA-MCH
        Network will be CSLab-GeneralLab

        Arguments:

        mac (str): a string containing the MAC address. The expected format
                is AA:BB:CC:DD:EE:FF. It is case-insensitive..
        sn (str): a string containing the serial number of the MCH. An example
               of serial number: 123456-1234
        net (str): a string containing the Network for the device.
        grp (str): a string containing the Ansible group to assign the MCH to.

        Returns:
            A dict with the description of the registered Host
        """

        if (grp != ""):
            response = self._con.create_host(
                sn,
                "MTCA-MCH",
                network=net,
                mac=mac,
                ansible_groups=[grp]
            )
        else:
            response = self._con.create_host(
                sn,
                "MTCA-MCH",
                network=net,
                mac=mac,
            )

        return response

    def validateNetwork(self, network):
        """Check if a network string is a valid CSEntry value

        Arguments:

        network (str): a string containing the network name that
                      the MCH will be registered to.
        Returns:
            A boolean flag where 'False' indicates that the network
            string is valid, and 'True' for invalid.

        """
        # Get list of available networks from CSEntry database
        self.getNetworks()
        # Check if provided network string is in the list from
        # the database
        for net in self.networks:
            if network == net['vlan_name']:
                return False

        return True

    def getNetworks(self):
        """Get list of available networks (e.g. CSLabGeneralLab, etc.) from CSEntry
        """

        self.networks = self._con.get_networks()
        # Print each Network so that we can pass back to the webui
        if isWebUI:
            for network in self.networks:
                print('~' + network['vlan_name'])

    def getGroups(self):
        """Get list of available networks (e.g. CSLabGeneralLab, etc.) from CSEntry
        """

        self.groups = self._con.get_groups()
        # Print each Network so that we can pass back to the webui
        if isWebUI:
            for group in self.groups:
                print('*' + group['name'])

    def validateGroup(self, group):
        """Check if an Ansible group string is a valid CSEntry value

        Arguments:

        group (str): a string containing the Ansible group that the
                     MCH will be a member of.
        Returns:
            A boolean flag where 'False' indicates that the group
            string is valid, and 'True' for invalid.

        """
        # Empty string is valid
        if (group == ""):
            return False
        else:
            # Get list of available groups from CSEntry database
            self.getGroups()
            # Check if provided group string is in the list from
            # the database
            for grp in self.groups:
                if group == grp['name']:
                    return False

        return True
if __name__ == '__main__':

    # Setup parser for input arguments
    parser = argparse.ArgumentParser(description='Helper script for the MHC config tool (Bash) to handle the access to the CSEntry API.')
    parser.add_argument('--mac-address', metavar='m', required=True, help='MAC address of the MCH to be registered')
    parser.add_argument('--serial-number', metavar='s', required=True, help='Serial number of the MCH to be registered')
    parser.add_argument('--network', metavar='n', default='CSLab-GeneralLab', help='Network that the MCH will be registered on in CSEntry')
    parser.add_argument('--group', metavar='g', default='', help='Ansible group that the MCH will be a member of')
    parser.add_argument('--network-query', metavar='q', type=bool, default=False, help='Query the CSEntry database for available networks')
    parser.add_argument('--ansible-query', metavar='a', type=bool, default=False, help='Query the CSEntry database for available ansible groups')
    parser.add_argument('--web-ui', metavar='w', type=bool, default=False, help='Flag to identify if we are being called from the web UI')
    parser.add_argument('--url', metavar='u', default='https://csentry-test.esss.lu.se/', help='CSEntry API URL')
    args = parser.parse_args()

    # Assign internal variables to parsed values from input
    url             = args.url
    isWebUI         = args.web_ui
    mac             = args.mac_address
    net             = args.network
    group           = args.group
    sn              = args.serial_number
    runNetworkQuery = args.network_query
    runAnsibleQuery = args.ansible_query

    # Check if an Ansible group is to be assigned
    assignGroup = True
    if (group == ""):
        assignGroup = False

    ## By now, the token should be written manually at deployment stage
    ## TODO: improve the handling of the token
    token='FILL-ME!!!'

    try:
        handler = CSEntryHandler(token=token, url=url)
        if runNetworkQuery:
            handler.getNetworks()
        elif runAnsibleQuery:
            handler.getGroups()
        else:
            # Check if provided network string is valid,
            # by checking against queried list from the database
            ret = handler.validateNetwork(net)
            if ret:
                print ("Provided network string (%s) is not valid." % net)
                exit (2)

            groupStr = ""
            if assignGroup:
                ret = handler.validateGroup(group)
                if ret:
                    print ("Provided Ansible group (%s) is not valid." % group)
                    exit (3)
                groupStr = ", and assigned to Ansible group: {}".format(str(group))

            # Continue to registration
            sn = "mch-{}".format(str(sn))
            ret = handler.searchHOST(mac)
            if ret == ():
                print("The MAC is not registered")
                device_descriptor = handler.registerNewHost(mac, sn, net, group)
                print("The new Host is registered to the {} as {} with the given IP: {}{}"
                .format(net,sn,device_descriptor['interfaces'][0]['ip'],groupStr))
            else:
                print ("The MCH was already registered @ CSEntry name={},IP={}".format(ret[0],ret[1]))
                exit (1)
    except Exception as e:
        print(e)
        exit(-2)

    exit(0)
