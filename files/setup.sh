#!/bin/bash

# Set user account that will manage OS post OVA deployment
USERD=root

#set -euo pipefail

# Check if Configuration has run already
if [ ! -f /${USERD}/ran_customization ]; 
then
	# Extract all OVF Properties
	VMTOOLSDSTATUS=$(systemctl show -p ActiveState vmtoolsd.service | sed 's/ActiveState=//g')
	CHASSISTYPE=$(hostnamectl status | grep Chassis| cut -d ':' -f 2 | cut -d ' ' -f 2)
	GUESTINFOTEST=$(/usr/bin/vmtoolsd --cmd 'info-get guestinfo.ovfEnv')
	IP_ADDRESS=$(/${USERD}/setup/getOvfProperty.py "guestinfo.ipaddress")
	#if [ $VMTOOLSDSTATUS == "active" ]; 
	if [ $CHASSISTYPE == "vm" ];
	then
		if [[ ! -z "$GUESTINFOTEST" ]];
		then
			if [[ ! -z "$IP_ADDRESS" ]];
			then
				echo -e "\e[92mVM Guest Info Detected. Configuring for VMware using Static IP ..." > /dev/console
				HOSTNAME=$(/${USERD}/setup/getOvfProperty.py "guestinfo.hostname")
				IP_ADDRESS=$(/${USERD}/setup/getOvfProperty.py "guestinfo.ipaddress")
				NETMASK=$(/${USERD}/setup/getOvfProperty.py "guestinfo.netmask" | awk -F ' ' '{print $1}')
				GATEWAY=$(/${USERD}/setup/getOvfProperty.py "guestinfo.gateway")
				DNS_SERVER=$(/${USERD}/setup/getOvfProperty.py "guestinfo.dns")
				DNS_DOMAIN=$(/${USERD}/setup/getOvfProperty.py "guestinfo.domain")
				NTP_SERVER=$(/${USERD}/setup/getOvfProperty.py "guestinfo.ntp")
				FALLBACKNTP_SERVER=$(/${USERD}/setup/getOvfProperty.py "guestinfo.fallbackntp")
				TIMEZONE=$(/${USERD}/setup/getOvfProperty.py "guestinfo.timezone")
				ROOT_PASSWORD=$(/${USERD}/setup/getOvfProperty.py "guestinfo.root_password")
				SSH_ENABLE=$(/${USERD}/setup/getOvfProperty.py "guestinfo.cis.appliance.ssh.enabled")
				SYSLOG_DESTINATION=$(/${USERD}/setup/getOvfProperty.py "guestinfo.syslogdestination")
				SYSLOG_PORT=$(/${USERD}/setup/getOvfProperty.py "guestinfo.syslogport")
				SYSLOG_PROTOCOL=$(/${USERD}/setup/getOvfProperty.py "guestinfo.syslogprotocol")
				LICENSE_INFO=$(/${USERD}/setup/getOvfProperty.py "guestinfo.license")
				##Comment out for no automation
				AUTOMATION_SELECTION=$(/${USERD}/setup/getOvfProperty.py "guestinfo.automation")
			else
				echo -e "\e[92mVM Guest Info Detected. Configuring for VMware using DHCP IP ..." > /dev/console
				HOSTNAME=$(/${USERD}/setup/getOvfProperty.py "guestinfo.hostname")
				IP_ADDRESS=""
				NETMASK=""
				GATEWAY=""
				DNS_SERVER=$(/${USERD}/setup/getOvfProperty.py "guestinfo.dns")
				DNS_DOMAIN=$(/${USERD}/setup/getOvfProperty.py "guestinfo.domain")
				NTP_SERVER=$(/${USERD}/setup/getOvfProperty.py "guestinfo.ntp")
				FALLBACKNTP_SERVER=$(/${USERD}/setup/getOvfProperty.py "guestinfo.fallbackntp")
				TIMEZONE=$(/${USERD}/setup/getOvfProperty.py "guestinfo.timezone")
				ROOT_PASSWORD=$(/${USERD}/setup/getOvfProperty.py "guestinfo.root_password")
				SSH_ENABLE=$(/${USERD}/setup/getOvfProperty.py "guestinfo.cis.appliance.ssh.enabled")
				SYSLOG_DESTINATION=$(/${USERD}/setup/getOvfProperty.py "guestinfo.syslogdestination")
				SYSLOG_PORT=$(/${USERD}/setup/getOvfProperty.py "guestinfo.syslogport")
				SYSLOG_PROTOCOL=$(/${USERD}/setup/getOvfProperty.py "guestinfo.syslogprotocol")
				LICENSE_INFO=$(/${USERD}/setup/getOvfProperty.py "guestinfo.license")
				##Comment out for no automation
				AUTOMATION_SELECTION=$(/${USERD}/setup/getOvfProperty.py "guestinfo.automation")
			fi
		fi
	fi

	# If Guest Info does not exist ask user to fill out fields
	if [ -z "$GUESTINFOTEST" ]; 
	then
		echo -e "\e[92mVMTools Guest Info not detected. Setting for DHCP ..." > /dev/console
		RANN=$(( $RANDOM % 10000 + 1 ))
		HOSTNAME="photon-$RANN.guarddog.ai"
		IP_ADDRESS=""
		NETMASK=""
		GATEWAY=""
		DNS_SERVER="8.8.8.8,8.8.4.4"
		DNS_DOMAIN="guarddog.ai"
		NTP_SERVER="0.pool.ntp.org"
		FALLBACKNTP_SERVER="1.pool.ntp.org"
		TIMEZONE="Etc/UTC"
		ROOT_PASSWORD="VMware12345!@#$%"
		SSH_ENABLE="True"
		SYSLOG_DESTINATION=""
		SYSLOG_PORT=""
		SYSLOG_PROTOCOL=""
		LICENSE_INFO="FREETRIAL"
		##Comment out for no automation
		AUTOMATION_SELECTION=""
		
		: '
		clear
		echo -e "\e[92mVMTools Guest Info not detected, Running Baremetal configurator ..." > /dev/console
		read -p "Do you wish to set a static IP address? y/n" yn
		clear
		case $yn in
		[Yy]* )
			read -p "Enter the Hostname (example fido.guarddog.lab): " HOSTNAME < /dev/tty
			clear
			read -p "Enter IPv4 address (example 172.26.5.100): " IP_ADDRESS < /dev/tty
			clear
			read -p "Enter Netmask (example 24 (24 is for 255.255.255.0)): " NETMASK < /dev/tty
			clear
			read -p "Enter the IP Gateway (example 172.26.4.1: " GATEWAY < /dev/tty
			clear
			read -p "Enter the DNS server(s) (examples 172.26.4.32 or 172.26.4.32,172.26.4.33): " DNS_SERVER < /dev/tty
			clear
			read -p "Enter the DNS domain (example guarddog.lab): " DNS_DOMAIN < /dev/tty
			clear
			read -p "Enter the Primary NTP Server (example 0.ntp.pool.org): " NTP_SERVER < /dev/tty
			clear
			read -p "Enter the Fallback NTP Server (example 1.ntp.pool.org) (leave blank for none): " FALLBACKNTP_SERVER < /dev/tty
			clear
			read -p "Please enter new $USERD password: " -s ROOT_PASSWORD < /dev/tty
			clear
			read -p "Do you wish to enable the SSH Client? y/n " sshyn < /dev/tty
			case $sshyn in
			[Yy]* )
				SSH_ENABLE = "True"
				clear
			;;
			[Nn]* )
				SSH_ENABLE = "False"
				clear
			;;
			* ) echo "Please answer yes or no." < /dev/tty;;
			esac
			;;
		[Nn]* )
			read -p "Enter the Hostname (example fido.guarddog.lab): " HOSTNAME < /dev/tty
			clear
			IP_ADDRESS=""
			NETMASK=""
			GATEWAY=""
			read -p "Enter the DNS server(s) (examples 172.26.4.32 or 172.26.4.32,172.26.4.33): " DNS_SERVER < /dev/tty
			clear
			read -p "Enter the DNS domain (example guarddog.lab): " DNS_DOMAIN < /dev/tty
			clear
			read -p "Enter the Primary NTP Server (example 0.ntp.pool.org): " NTP_SERVER < /dev/tty
			clear
			read -p "Enter the Fallback NTP Server (example 1.ntp.pool.org) (leave blank for none): " FALLBACKNTP_SERVER < /dev/tty
			clear
			read -p "Please enter new $USERD password: " -s ROOT_PASSWORD < /dev/tty
			clear
			read -p "Do you wish to enable the SSH Client " sshyn < /dev/tty
			case $sshyn in
			[Yy]* )
				SSH_ENABLE = "True"
				clear
			;;
			[Nn]* )
				SSH_ENABLE = "False"
				clear
			;;
			* ) echo "Please answer yes or no." < /dev/tty;;
			esac
			;;
		* ) echo "Please answer yes or no." < /dev/tty;;
		esac
		'
	fi
fi

if [ -e /${USERD}/ran_customization ]; 
then
    exit
else

	echo -e "\e[92mStarting Customization ..." > /dev/console

	echo -e "\e[92mStarting OS Configuration ..." > /dev/console
	. /${USERD}/setup/1-setup-os.sh
	sleep 20
	
	echo -e "\e[92mStarting Network Configuration ..." > /dev/console
	. /${USERD}/setup/2-setup-network.sh
	sleep 20
	
	##Comment out for no repo scripting downloads
	echo -e "\e[92mStarting Repo Install ..." > /dev/console
	. /${USERD}/setup/3-install-repo-scripts.sh 
	sleep 20
	
	##Comment out for no automation
	echo -e "\e[92mStarting Automation ..." > /dev/console
	. /${USERD}/setup/4-setup-automation.sh 
	sleep 20
	
	echo -e "\e[92mResizing Partition (if needed) ..." > /dev/console
	. /${USERD}/setup/resize.sh /dev/sda 3
	sleep 20
	
	echo -e "\e[92mCustomization Completed ..." > /dev/console

	# Clear guestinfo.ovfEnv
	#vmtoolsd --cmd "info-set guestinfo.ovfEnv NULL"

	# Ensure we don't run customization again
	touch /${USERD}/ran_customization
	
	#Reboot
	sudo reboot
fi
