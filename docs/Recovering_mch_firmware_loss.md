

Monday, May 13 16:28:06 CEST 2019 han.lee@esss.se

During the firmware upgrading, from time to time, MCH cannot be in the proper booting stage. They may have the following stage such as 
```
    **************************************************
    **** Welcome to OK1 V2.0 for NAT-MCH          ****
    ****------------------------------------------****
    **** Core Release: V1.13                      ****
    **** BSP  Release: V1.13 Final                ****
    **** Build       : Jun 26 2013 11:33:14       ****
    **************************************************
 
initializing ... >H>sysMemInit: ram_addr=4016bc38, ram_end=42000000
M>I>mbinit()
MB>T>C>S <
 
isdnSupInit: c_pool=0x41f9bfd0 pool size=262144 for 8192 container
 
Board Configuration Information:
--------------------------------
Board Identifier: 113521-0969
Serial Number   : 969
Manufacturer ID : 01
Board Code      : 1135
Layout Version  : 2.1
Revison Code    : 150127
CPU             : Coldfire / 200 MHz
DRAM            : 32 MB
SRAM            : 32 KB
EEPROM          : 32 MB
SIO             : 19200 baud (0 default)
IEEE Address    : 00-40-42-22-03-c9
--------------------------------
TCP/IP Configuration:
nat0 interface configuration:
   IP Address   : 192.168.1.41
   IP Net Mask  : 255.255.255.0
   IP Broadcast : 192.168.1.255
   IP Gateway   : 0.0.0.0
Boot String     : <empty>
--------------------------------
usbInit2 ....
 
********************************************************
*** MCH Bootloader V2.6b beta (11:30:34 Jun 24 2013) ***
********************************************************
 
HW: PCB V2.1 Rev 150127    FPGA V1.14
 
BSP V1.13 Final (11:33:26 Jun 26 2013)
Bootloader
TFTP V2.5 Final (11:33:09 Jun 26 2013)
TCP/IP V1.40 Final (11:32:30 Jun 26 2013)
Telnet daemon support
compiled with GCC 2.95
instruction cache enabled
data cache enabled
 
DRAM size: 32 MB
 
appInit: OK1 kernel started - starting bootloader ...
 
Press 'x' to abort firmware startup..........
Booting firmware from network ...
 
nat> FEC DRV V1.18 Final (11:32:16 Jun 26 2013)
 
BCM5482 driver V1.2 Final (11:32:22 Jun 26 2013)
BCM5396 DRV V1.18 Final (11:32:23 Jun 26 2013)
 
tcpipMain: starting TCP/IP ...
natattach: nat0 00:40:42:22:03:c9 attached
loattach: lo 00:40:42:22:03:c9 attached
tcpipMain: configure loopback interface lo 127.0.0.1
tcpipMain: TCP/IP started
usbDeviceInit: Starting USB Device mode driver ...
 
USB: Cable attach detected.
 
*** starting network configuration ***
configure network interface nat0 192.168.1.41
no nat0 gateway configuration
TELNETD: start daemon
 
TFTP FW: ERR - no bootstring
Transmit task started
Timer task started
TELNETD: started - listen on port 23
 
nat>
nat>
```
The most of commands do not work in their console. One has the following situation, please follow the instruction. 



## Setup ip address statically


* Type `x` to stop the existent firmware startup...

```
nat> reboot

Press 'x' to abort firmware startup..........
....
```

* Find the available "free" ip address. ESS Office network information as below


```
nat> ip
IP Configuration Setup:
-----------------------
IP Address           : 10.0.7.14
IP Net Mask          : 255.255.252.0
IP Broadcast Addr    : 10.0.4.1
IP Gateway Addr      : 10.0.4.1
-----------------------
Writing the configuration record to serial EEProm:

Are you really sure ?y

```

* Reboot





## Update the latest firmware 

* Type `x` to stop the existent firmware startup...

```
nat> reboot
....

appInit: OK1 kernel started - starting bootloader ...

Press 'x' to abort firmware startup..........
```
* Type the tftp ip and its firmware name

```
nat> update_firmware

Update firmware into FLASH at offset 0x00100000:

--------------------------------------------------
Enter host and file name [IP:FILENAME]:
firmware> 10.0.4.189:latest_mch_fw.bin
TFTP: getting BIN file:
  10.0.4.189:latest_mch_fw.bin

```


##  Write the Boot String


```
nat> reboot

nat> bi

Board Configuration Information:
--------------------------------
Board Identifier: 113521-0963
Serial Number   : 963
Manufacturer ID : 01
Board Code      : 1135
Layout Version  : 2.1
Revison Code    : 150127
CPU             : Coldfire / 200 MHz
DRAM            : 32 MB
SRAM            : 32 KB
EEPROM          : 32 MB
SIO             : 19200 baud (0 default)
IEEE Address    : 00-40-42-22-03-c3
--------------------------------
TCP/IP Configuration:
nat0 interface configuration:
   IP Address   : 192.168.1.41
   IP Net Mask  : 255.255.255.0
   IP Broadcast : 192.168.1.255
   IP Gateway   : 0.0.0.0
Boot String     : <empty>
--------------------------------
```

One can see the Boot String is <empty>. With `bs` onr should type **0xd0100008** as the base address of the fireware. I've checked that value in several MCHs, and it is the identical value. There is no information which I can find in any technical documents provided by NAT.

```
nat > bs
Enter new boot string: 

Writing the configuration record to serial EEProm:

Are you really sure ?y

DBG - boardCfgWriteDirect: boardCfg.csum=0x217e
................................

nat> reboot 
```





