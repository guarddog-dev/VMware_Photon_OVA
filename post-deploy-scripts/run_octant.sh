#!/bin/bash

#Run Octant

#NOTE: The accepted-hosts is the IP of your remote workstation
IPADDRS=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
OCTANTPORT=7777
USERIP=$(who | cut -d"(" -f2 |cut -d")" -f1)
echo "Open a browser to http://$IPADDRS:$OCTANTPORT to access Octant Web Interface Remotely"
octant --disable-open-browser --disable-origin-check --accepted-hosts $USERIP


