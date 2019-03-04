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
