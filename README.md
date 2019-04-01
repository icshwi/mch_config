ESS MTCA NAT MCH Configuration
======

**This module is under development.**

MCH Configuration is one of teadious and combersome procedures. This repository
may help users to configure their NAT MCH with minimum efforts. With tftp, 
expect, and shell scripts, ICS at ESS would like to develop an automation tool
to configure the NAT MCH massively. 

Currently, we are in the stage to find the optimal solution and the standard
configuration options of MCH per a ESS Standard 3U and 9U MTCA System 
Configuration. This repository can hold almost all resouces for NAT MCH
configuration. 

## Requirements

* A TFTP Server 
* Expect 
* Configuration of TFTP according to the directory structure, shown in `Current TFTP Server Configuration at ESS`
* MOXA Serial Server NPort 6650-16
* In-house Serial Cable between MCH and MOXA (One has to understand MOXA pinout and NAT MCH pinout properly. Note that one can find few discrepencies among NAT MCH manuals. )

For the set up of the WebUI:

- Apache (or similar) WebServer
- Websocketd

### Expect
We use the expect to configure the MCH within four steps. Please look at
[How to use expect commands](expect/README.md). Expect scripts already know the following the TFTP directory structure and its corresponding files as well.

### Current TFTP Server Configuration at ESS

```
$ cd tftp_path
$ tree -L 3
.
├── conf
│   ├──  nat_mch_fw2.20.4_3u_cfg.txt -> /home/iocuser/ics_gitsrc/mch_config/src/nat_mch_fw2.20.4_3u_cfg.txt
│   └──  nat_mch_fw2.20.4_9u_cfg.txt -> /home/iocuser/ics_gitsrc/mch_config/src/nat_mch_fw2.20.4_9u_cfg.txt
├── fw
│   └── 2.20.4
│       └──  mch_fw_2_20_4.bin
├── latest_mch_conf_3u_cfg.txt -> conf/nat_mch_fw2.20.4_3u_cfg.txt
├── latest_mch_conf_9u_cfg.txt -> conf/nat_mch_fw2.20.4_9u_cfg.txt
└── latest_mch_fw.bin -> fw/2.20.4/mch_fw_2_20_4.bin
```

### MOXA NPort 6650-16 Configuration


|![MOXA1](images/moxa_config_01.png)|
| :---: |
|**Figure 1** The screenshot for MOXA NPORT Configuration : Operation Modes. |


|![MOXA1](images/moxa_config_02.png)|
| :---: |
|**Figure 2** The screenshot for MOXA NPORT Configuration : Communication Paremeters. |

## Deployment of the WebUI

A more flexible and fast way to use the configuration tool relies on the use of a Web User Interface (WebUI). In order to use it, the **mch_config** tool must be previously configured system wide.

Right now, only Debian and Ubuntu are supported by the tool. In order to install the UI, just type in the root folder of the project `sudo make all`. This will copy the scripts and configuration files in */usr/local/share/mch_config* and it will install the [Websocketd](<http://websocketd.com/>) service and the web server with the UI.

Then, check that Websocketd system service is OK:

```
$ sudo systemctl status websocketd.service 
● websocketd.service - Run websocketd as a system service
   Loaded: loaded (/etc/systemd/system/websocketd.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2019-03-27 14:22:12 CET; 7min ago
 Main PID: 15130 (websocketd)
    Tasks: 8 (limit: 4915)
   CGroup: /system.slice/websocketd.service
           ├─15130 /usr/bin/websocketd --port=8080 /usr/local/share/mch_config/script/wsmanager.bash
           └─16717 bash /usr/local/share/mch_config/script/wsmanager.bash
```

Now, you can access to the UI using a web browser and the IP address of the server:

![](/home/felipe/workspace/mch_config/images/webui.png)



## How to use the configuration tool

### Command line tool

The file *script/mch_config.bas* contains a wrapper script that can interface to all the individual steps managed by *expect* scripts. Also this script can run multiple MCH configuration procedures at once, the only requirement needed is that all of them must have the same form factor. 

The following shows the output of the help information from the script:

```
Usage: mch_config.sh MOXA_IP <port range> <form factor> [options]
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
                  1 -> FW update (default)
                  2 -> DHCP network configuration (default)
                  3 -> Standard MCH configuration (default)
                  4 -> Clock configuration
                  5 -> Check the configuration
                  By default, the script is executed with options: 					  1,2,3,5
  -p|--prefix    -> Source prefix for the tool. By default is "../".
  -l|--log       -> Log prefix. By default is "../log"

Examples:
Run the script to update FW only in the port 4010:
    mch_config.sh 10.0.5.173 10, -s 1
Run the script to configure DHCP in ports 10 to 14:
    mch_config.sh 10.0.5.173 10-14 --steps 2
Run the script with the default steps on ports 10,11 and 15:
    mch_config.sh 10.0.5.173 10,11,15
```

A detailed explanation about some of the arguments:

- **port range:** Since the script allows the user to configure many MCHs at the same time, it's needed to introduce a list of ports for the MOXA hub. To make your life easy, some tricks has been done in order to reduce the amount of characters that you need to introduce: you can select a port range or a list of individual ports just splitting by commas. **But don't forget to introduce a comma character even when you select only on port number!**.
- **form factor:** This argument is needed to specify which clock configuration we need to apply. I couldn't find any reliable way to detect this, sorry for the inconvenience!
- **steps:** By default the script: updates the FW, set up DHCP and writes the general configuration of MCH (and checks it!). If the user wants to run just some steps, use this option to select which steps do you want to run. 
- **prefix:** Don't need to touch.
- **log:** Folder to store the log from the script. Logs from expect scripts will be placed in */tmp/mch_conf*.

Since we expect to use this within a GUI, there's no output from the script to the standard output (console). You can check the log of the script from the *log* folder. **Hint**: use *tail -F*. 



### WebUI

There's is a web user interface for the tool as shown in the section about *Deployment of the WebUI*. This web interfaces with the same Bash script. It is built with HTML+Javascript and uses  [Websocketd](<http://websocketd.com/>) to interface between the web server and the execution of a Bash script.

Once you enter in the web, the "Send" button will be green only if the connection is working. You can select the IP address of the MOXA and in which ports you want to run the configuration. Firmware version selection is not implemented yet.

The first row enables the selection of all the ports at once. In addition to choose the port number, you can specify if you want to run the clock configuration. Keep **NA** to avoid this configuration, or select **3U** or **9U** to configure the clock on a selected port.

Right now, there is no feedback from the Bash script, so once you press **Send**, you can't check the status unless you manually open the log files. Provide some feedback in the web is planned for a future version.