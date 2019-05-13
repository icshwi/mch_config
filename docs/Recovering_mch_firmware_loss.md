

Monday, May 13 16:28:06 CEST 2019 han.lee@esss.se

## Setup ip address statically


* Type `x` to stop the existent firmware startup...

```
nat> reboot

Press 'x' to abort firmware startup..........
....

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


One can see the Boot String is <empty>
nat > bs
Enter new boot string: 0xd0100008

Writing the configuration record to serial EEProm:

Are you really sure ?y

DBG - boardCfgWriteDirect: boardCfg.csum=0x217e
................................

nat> reboot 
```





