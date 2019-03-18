Expect for automation configuration for MCH
=====

# Pure expect script

This script is used for the MCH configuration through MOXA serial server. And it is just an idea how we use this tool to make the MCH configuration easily. The current version can cover the almost all configuration through `mchcfg`, `ip`, and so on. In order to use this script, it is necessary to setup MOXA serial server correctly.


## Commands


### Step 1
In case, we don't have the fixed ip address, we have to enable DHCP via

```
expect (master)$ expect dhcp.exp 10.0.5.173 4016
```
After step 1, the MCH will be rebooted. 


### Step 2
One should update the latest firmware. 
```
expect (master)$ expect fwupdate.exp 10.0.5.173 4016
```
After step 2, the MCH will be rebooted. 

### Step 3
one should update the ESS Default MCH configuration
```
expect (master)$ expect mchconf.exp 10.0.5.173 4016
```
After step 3, the MCH will be rebooted. 

### Step 4
We update the following configuration with this step. We cannot setup some configuration without the dedicated file. 
* Clock Distribution Configuration
* a Virtual Switch of the PCIe switch
* PCIe speed of a switch 
* upstream slot power up delay time in seconds (This is the duplicated one in Step 3)

After step 4, the MCH will be rebooted. 

**ESS MTCA 3U System**

```
expect (master)$ expect clock_update_3u.exp 10.0.5.173 4016
```

**ESS MTCA 9U System**

```
expect (master)$ expect clock_update_9u.exp 10.0.5.173 4016
```

## Debugging NAT MCH

Because we have the fixed the MOXA Server with the same configuration, we can use the following command
to access a MCH CLI also. However, there is only one valid connection. 
```
telnet 10.0.5.173 4016
```

Note that one cannot use `copy-and-paste`, because of the limited resouces of NAT MCH. One has to type all command by hand, is highly recommended. 


## Warning

One should not make all enable in the all debug in web interface, because NAT MCH doesn't have enough
resource to handle huge of debug messages at all. Moreover, one cannot use any expect commands either. 
In case, one has this situation. Please try to access the web interface to disable them as much as one can. 
It may need 30 mins to recover this situation. 


## pexpect : Python
Since we don't have any resource right now, we postpone to develop it with Python script. 

# Bash wrapper

The file *mch_config.sh* contains a wrapper script that can interface to all the individual steps managed by *expect* scripts. Also this script can run multiple MCH configuration procedures at once, the only requirement needed is that all of them must have the same form factor. 

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
                  By default, the script is executed with options: 1,2,3,5
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

Since we expect to use this within a GUI, there's no output from the script to the standard output (console). You can check the log of the script from the *log* folder. **Hint**: use *tail -F*.