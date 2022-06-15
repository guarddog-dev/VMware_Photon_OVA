#!/bin/bash

# Set user account that will configure OS post OVA deployment
USERD=root

# OS Specific Settings where ordering does not matter

#set -euo pipefail

# Set SSH Settings
if [ "$SSH_ENABLE" = "True" ];
then
	echo -e "\e[92m  Configuring SSH Daemon ..." > /dev/console
	#Regenerate SSH Keys
	sudo dpkg-reconfigure openssh-server
	#Enable Services
	sudo systemctl enable sshd
	sudo systemctl start sshd
fi
if [ "$SSH_ENABLE" = "False" ];
then
	echo -e "\e[92m  Disabling SSH Daemon ..." > /dev/console
	#Regenerate SSH Keys
	sudo dpkg-reconfigure openssh-server
	#Enable Services
	sudo systemctl disable sshd
	sudo systemctl stop sshd
fi


# Allow ICMP
echo -e "\e[92m  Enabling ICMP ..." > /dev/console
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
sudo iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
sudo iptables-save > /etc/systemd/scripts/ip4save

# Set User Password
echo -e "\e[92m  Configuring OS $USERD password ..." > /dev/console
echo "${USERD}:${ROOT_PASSWORD}" | sudo /usr/sbin/chpasswd

#Set administrator account attributes
#echo "\e[92m  Setting administrator password requirements per CIS guidance ..." > /dev/console
sudo chage -m 1 root

#Set Timezone
echo -e "\e[92m  Setting Timezone to $TIMEZONE ..." > /dev/console
sudo timedatectl set-timezone $TIMEZONE
