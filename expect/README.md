Expect for automation configuration for MCH
=====

## Pure expect script

This script is used for the MCH configuration through MOXA serial server. And it is just an idea how we use this tool to make the MCH configuration easily. The current version can cover the almost all configuration through `mchcfg`, `ip`, and so on. In order to use this script, it is necessary to setup MOXA serial server correctly.


### `MCH CFG: configuration modes`

```
  [ 3] modify MCH global configuration
  [ 4] modify ShM configuration
  [ 5] modify CM configuration
  [ 6] modify SEL configuration
  [ 7] modify GbE switch configuration
  [ 8] modify CLK module configuration
  [ 9] modify PCIe configuration
  [10] modify NTP configuration
  [11] modify DHCP configuration
```
### `Debugging Support`

```
  csif_dbg                 - configure CM/ShM interface debug
  imsg_dbg                 - configure IPMI MSG debug
  lshm_dbg                 - configure local ShM debug
  red_dbg                  - configure redundancy debug
  rmcp_dbg                 - configure RMCP interface debug
  sdrrep_dbg               - configure SDR repository debug
  sel_dbg                  - configure SEL debug
```
### `MCH ip configuration`
```
ip                     - IP configuration setup
```

### Command

```
expect (master)$ expect mchconf.exp 10.4.8.102 4001
```

# MOXA address for testing
```
telnet 10.4.8.102 4001
```

## pexpect : Python
Since we don't have any resource right now, we postpone to develop it with Python script. 
