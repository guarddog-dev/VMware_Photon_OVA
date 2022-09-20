#!/bin/bash

#Run Octant

#Set Octant IP/port (default is 7777)
IPADDRS=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
OCTANTPORT=7777

#Open Firewall Port for externel access
sudo iptables -I INPUT -p tcp -m tcp --dport $OCTANTPORT -j ACCEPT
#sudo iptables-save > /etc/systemd/scripts/ip4save

#Start Octant
#NOTE: The accepted-hosts is the IP of your remote workstation
USERIP=$(who | cut -d"(" -f2 |cut -d")" -f1)
echo "Open a browser to http://$IPADDRS:$OCTANTPORT to access Octant Web Interface Remotely"
octant --disable-open-browser --disable-origin-check --accepted-hosts $USERIP --listener-addr $IPADDRS:$OCTANTPORT

