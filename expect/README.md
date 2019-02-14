Expert for automation configuration for MCH


## Pure expect script

This script is used for the MCH configuration through MOXA serial server. And it is just an idea how we use this tool to make the MCH configuration easily. The current version 0.0.1 changes only the NTP server configuation and sync MCH time with them. 

```
expect (master)$ expect mchconf.exp 10.4.8.102 4001
```


## pexpect : Python
