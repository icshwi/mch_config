remote interfaces:

Management interface at GbE port : disabled
RMCP access : enabled
telnet access : enabled
ssh access : disabled (find out how to enable it)
WEB access : enabled 
IP address source for management port : 
* board configuration (LAB)
* DHCP (SITE)

IP address source for GbE port : no IP address
RMCP session activity timeout minutes : 0
RMCP session activity timeout seconds : 60
Telnet session activity timeout seconds : 300
default fan level : 40


enable watch dog timer : no
Enable alternative cooling scheme : no
PM Assignment strategy : strict
Use BM (MCH-RTM) as PM for eRTM15 : no
IPMI Compatibility Mode : enable (will ask this an expert)

Shelf manager parameter

allow shelf FRU invalid : yes
temperature management	: enabled
emergency shutdown : disabled
Send SEND_MSG confirmation to SMS : disabled
use external shelf manager : no

Carrier manager parameter

carrier number default : 0
quiesced event timeout : 30

allow carrier FRU invalid : yes
overrule carrier FRU : no
shutdown system if MCH goes down : no (requirement is necessary for yes)
enable Clock E-keying : no 


IPMI diabled	
FRU	
E-keying	
sensor	
event	
power module	
cooling unit	
CM/ShM interface	
FRU communication to debug (0=all)	 0

keep on read	: disabled
allocate SEL in non-volatile RAM : no	
ignore 'version change' sensor : no

Ethernet switch parameter
configuration source	: no configuration
Ignore Backplane FRU Info : no

Clock module parameter
configuration source : load from FLASH


upstream slot power up delay :	15 
PCIe hot plug delay for AMCs :	0 
100 MHz spread spectrum	 : disabled
hot plug support	: disabled 
PCIe early ekey (before payload) : disabled	
'no ekey' for PCIe	 : disabled 
Use PCIe on MCH-RTM(disable AMC12) : no
configuration source : no configuration / load from FLASH


Time Protocol/SNTP parameter

Time server IP	: 172.16.6.38 
'Check for Time' delay minutes	: 0
'Check for Time' delay hours :
local time offset : 
configuration flags:
SNTP or Time Protocol	
Time client

SNTP or Time Protocol	: Time protocol
Time client : diabled

Host name : 

SNMP server	: diabled
Destination IP for SNMP Traps : 0.0.0.0





Xilinx Virtual Cable parameter :Global (but only lab will figure out later)
Xilinx Virtual Cable Server : disabled
Base TCP Port
Maximal User defined JTAG Frequency  


IPMI monitor over ethernet

IPMI Monitor	
Target IP Address	
Target UDP Port


Primary IP parameter	Current Configuration
Primary IP	
Primary IP Address	
0
 .  
0
 .  
0
 . 
0
Primary IP Netmask	
0
 .  
0
 .  
0
 . 
0
Primary IP Gateway	
0
 .  
0
 .  
0
 . 
0

