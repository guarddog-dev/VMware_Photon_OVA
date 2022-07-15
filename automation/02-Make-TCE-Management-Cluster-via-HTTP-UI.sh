#!/bin/bash
echo '  Preparing for Tanzu Community Edition Management Cluster Web UI ...'

# Set Variables
IFACE=eth0

##Build Management Cluster using UI Web Interface
echo '   Setting Tanzu Community Edition Management Cluster Web UI port to 8080...'
TCEBUILDPORT=8080
IPADDRS=$(ip a s $IFACE | egrep -o "inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | cut -d" " -f2)

#Create firewall rule
echo '   Adding Port 8080 to IPTables...'
#sudo ufw allow $TCEBUILDPORT/tcp #Ubuntu
sudo iptables -I INPUT -p tcp -m tcp --dport 8080 -j ACCEPT #PhotonOS

#Start UI Web Interface
echo '   Starting Tanzu Management Cluster Web UI on $IPADDRS:8080...'
echo '   Please one a web browser to  http://$IPADDRS:8080 to access the UI interface to get started...'
#note: calico is added for Ubuntu OS
tanzu management-cluster create --bind "$IPADDRS:8080" --ui
