#!/usr/bin/env python
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
__copyright__ = "Copyright 2020, European Spallation Source"
__license__   = "GPL"
__version__   = "1.0"
__email__     = "felipe.torresgonzalez@ess.eu"
__status__    = "Development"

import sys

from csentry import CSEntry

class CSEntryHandler:
    """CSEntry handler

    This class provides the main functionality to interface with CSEntry. It
    also provides methods to perform the required actions by the MCH tool:
    - Check if a MAC address already exists in the DB
    - Create a new host device and associate the MAC address and hostname
      based on a specific MCH.
    """

    def __init__(self, token, url='https://csentry.esss.lu.se/'):
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

    def registerNewHost(self, mac, sn, net="CSLab-GeneralLab"):
        """Register a new host in CSEntry

        A new host device will be registered with the given data.

        Hostname will be mch-<serial number>.cslab.esss.lu.se
        Device type will be MTCA-MCH
        Network will be CSLab-GeneralLab

        Arguments:

        mac (str): a string containing the MAC address. The expected format
                is AA:BB:CC:DD:EE:FF. It is indiferent to use capital
                letters or not.
        sn (str): a string containing the serial number of the MCH. An example
               of serial number: 123456-1234
        net (str) : a string containing the Network for the device.

        Returns:
            A dict with the description of the registered Host
        """
        response = self._con.create_host(
            sn,
            "MTCA-MCH",
            network=net,
            mac=mac
        )
        return response

if __name__ == '__main__':

    if len(sys.argv) < 3:
        print("Usage: mchHandler.py <mac> <sn> [API URL]")
        exit(-1)

    # By now, the token should be written manually at deployment stage
    # TODO: improve the handling of the token
    token='FILL-ME!!!'

    if len(sys.argv) > 3:
        url=str(sys.argv[3])
    else:
        url='https://csentry-test.esss.lu.se/'

    try:
        handler = CSEntryHandler(token=token, url=url)
        mac = sys.argv[1]
        sn = "mch-{}".format(str(sys.argv[2]))
        ret = handler.searchHOST(mac)
        if ret == ():
            print("The MAC is not registered")
            device_descriptor = handler.registerNewHost(mac, sn)
            print("The new Host is registered as mch-{} with the given IP: {}".format(sn,device_descriptor['interfaces'][0]['ip']))
        else:
            print ("The MCH was already registered @ CSEntry name={},IP={}".format(ret[0],ret[1]))
            exit (1)
    except Exception as e:
        print(e)
        exit(-2)

    exit(0)
