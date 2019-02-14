#!/usr/bin/env python



import pexpect

child = pexpect.spawn('telnet 10.4.8.102 4001')

index = child.expect ([pexpect.TIMEOUT], 1)
if index == 0:
    child.send('\r')

child.setecho(False)    
child.expect('nat> ')
child.write('h\r')
child.expect('nat> ')
child.send('ifconfig\r')
child.expect('nat> ')
child.send('\r')
print child.before   # Print the result of the ls command.
child.interact()     # Give control of the child to the user.




