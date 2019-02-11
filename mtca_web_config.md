# NAT MCH Web configuration

## Base configuraton

### 

| **MCH global paramter**    | **Configuration**         | comment|
| ---------------------- | :-------------------: |-------:|
| **remote interfaces**  |                       | |
Management interface at GbE port | disabled 
RMCP access | enabled
telnet access | enabled
ssh access | disabled | find out how to enable it
WEB access | enabled 
IP address source for management port | board configuration |LAB
IP address source for management port | DHCP | SITE
IP address source for GbE port | no IP address
RMCP session activity timeout minutes | 0
RMCP session activity timeout seconds | 60
Telnet session activity timeout seconds | 300
default fan level | 40
| **MCH configuration flags** |                       | |
enable watch dog timer | no
Enable alternative cooling scheme | no
PM Assignment strategy | strict
Use BM (MCH-RTM) as PM for eRTM15 | no
IPMI Compatibility Mode | enable | will ask this an expert



###

| **Shelf manager parameter**| **Configuration**         | comment|
| ---------------------- | :-------------------: | ------:|
allow shelf FRU invalid | yes
temperature management	| enabled
emergency shutdown | disabled
Send SEND_MSG confirmation to SMS | disabled
use external shelf manager | no


###
| **Carrier manager parameter**| **Configuration**         | comment|
| ---------------------- | :-------------------: | ------:|
carrier number default | 0
quiesced event timeout | 30
**configuration flags**|
allow carrier FRU invalid | yes
overrule carrier FRU | no
shutdown system if MCH goes down | no | requirement is necessary for yes
enable Clock E-keying | no 
**debug flags**|
IPMI | disabled	
FRU	| disabled 
E-keying	| disabled 
sensor	| disabled 
event	| disabled 
power module | disabled 	 
cooling unit	| disabled 
CM/ShM interface	| disabled  
FRU communication to debug (0=all) |	 0

###
| **SEL parameter**      | **Configuration**         | comment|
| ---------------------- | :-------------------: | ------:|
**configuration flags**|
keep on read	| disabled
allocate SEL in non-volatile RAM | no	
ignore 'version change' sensor | no


###
| **Ethernet switch parameter** | **Configuration**         | comment|
| ---------------------- | :-------------------: | ------:|
configuration source	| no configuration
Ignore Backplane FRU Info | no

###
| **Clock module parameter** | **Configuration**         | comment|
| ---------------------- | :-------------------: | ------:|
configuration source | load from FLASH

###
| **PCIe parameter**      | **Current Configuration**         | comment|
| ---------------------- | :-------------------: | ------:|
**configuration flags**|
upstream slot power up delay |	15 
PCIe hot plug delay for AMCs |	0 
100 MHz spread spectrum	 | disabled
hot plug support	| disabled 
PCIe early ekey (before payload) | disabled	
'no ekey' for PCIe	 | disabled 
Use PCIe on MCH-RTM(disable AMC12) | no
configuration source | no configuration | load from FLASH


###

| **Time Protocol/SNTP parameter**  | **Current Configuration**  | comment|
| ---------------------- | :-------------------: | ------:|
Time server IP	| 172.16.6.38 
'Check for Time' delay minutes	| 0
'Check for Time' delay hours | 0
local time offset | 0
**configuration flags**|
SNTP or Time Protocol	| Time protocol
Time client | diabled


###
| **DHCP parameter**      | **Current Configuration**         | comment|
| ---------------------- | :-------------------: | ------:|
Host name | 


###
| **SNMP parameter**     | **Current Configuration**         | comment|
| ---------------------- | :-------------------: | ------:|
SNMP server	| diabled
Destination IP for SNMP Traps | 0.0.0.0





### 
| **Xilinx Virtual Cable parameter** | **Current Configuration** | comment|
| ---------------------- | :-------------------: | ------:|
Xilinx Virtual Cable Server | disabled | Global in LAB
Base TCP Port | 254 | 254
Maximal User defined JTAG Frequency  || 



 
### 
| **IPMI monitor over ethernet** | **Current Configuration** | comment|
| ---------------------- | :-------------------: | ------:|
IPMI Monitor      	|    | will be defined globally
Target IP Address   |	 | will be defined globally
Target UDP Port | 623 |

 
### 
| **Primary IP parameter** | **Current Configuration** | comment|
| ---------------------- | :-------------------: | ------:|
Primary IP	        | disabled |
Primary IP Address	| 0.0.0.0  |
Primary IP Netmask  | 0.0.0.0  |
Primary IP Gateway	| 0.0.0.0  |

```
