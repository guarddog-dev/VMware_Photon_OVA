#!/bin/bash

# Setup Networking

# Set user account that will configure OS post OVA deployment
USERD=root

#set -euo pipefail

# Set Static IP Address
# create yaml file and move it to netplan folder
if [[ ! -z "$IP_ADDRESS" ]];
then
echo -e "\e[92m  Configuring Static IP Address ..." > /dev/console
NETWORK_CONFIG_FILE=$(ls /etc/systemd/network | grep .network)
cat > /etc/systemd/network/${NETWORK_CONFIG_FILE} << __CUSTOMIZE_PHOTON__
[Match]
Name=e*

[Network]
Address=${IP_ADDRESS}/${NETMASK}
Gateway=${GATEWAY}
DNS=${DNS_SERVER}
Domain=${DNS_DOMAIN}
__CUSTOMIZE_PHOTON__
fi

# Setup DHCP IP Address
# create yaml file and move it to netplan folder
if [ -z "$IP_ADDRESS"  ]; 
then
	echo -e "\e[92m  IP Address Not Set. Setting up DHCP ..." > /dev/console
fi

# Set DNS Resolution
if [[ ! -z "$DNS_SERVER" ]];
then
        echo -e "\e[92m  Configuring DNS Resolution ..." > /dev/console
        sudo rm -f /etc/resolv.conf
        cd /${USERD}/setup

        if [[ $DNS_SERVER == *,* ]];
        then
                IFS=', ' read -r -a DNSLIST <<< "$DNS_SERVER"
                readarray -td, DNSLIST <<<"$DNS_SERVER"; declare -p DNSLIST;
                DNS1=$(echo "${DNSLIST[0]}")
                DNS2=$(echo "${DNSLIST[1]}")
        fi

        if [[ $DNS_SERVER != *,* ]];
        then
                DNS1=$DNS_SERVER
        fi

        if [[ -z "$DNS2" ]];
        then
                sudo echo "nameserver $DNS1" > resolv.conf
                sudo echo "options edns0 trust-ad" >> resolv.conf
                sudo echo "search ${DNS_DOMAIN}" >> resolv.conf
        fi

        if [[ ! -z "$DNS2" ]];
        then
                sudo echo "nameserver $DNS1" > resolv.conf
                sudo echo "nameserver ${DNS2}" >> resolv.conf
                sudo echo "options edns0 trust-ad" >> resolv.conf
                sudo echo "search ${DNS_DOMAIN}" >> resolv.conf
        fi
        sudo mv resolv.conf /etc/resolv.conf
fi

# Set Chrony NTP Servers
echo -e "\e[92m  Configuring Chrony NTP Time Sync ..." > /dev/console
sudo mv /etc/chrony.conf /${USERD}/setup/chrony.conf 
sudo chmod 0777 /${USERD}/setup/chrony.conf
if [[ ! -z "$NTP_SERVER" ]];
then
	echo "server $NTP_SERVER" >> /${USERD}/setup/chrony.conf
fi
if [[ ! -z "$FALLBACKNTP_SERVER" ]];
then
	echo "server $FALLBACKNTP_SERVER" >> /${USERD}/setup/chrony.conf
fi
sudo mv /${USERD}/setup/chrony.conf /etc/chrony.conf
sudo timedatectl set-ntp true
sudo systemctl disable systemd-timesyncd

# Set Hostname
echo -e "\e[92m  Configuring Hostname ..." > /dev/console
sudo cp /etc/hosts /${USERD}/setup/hosts
SHORTNAME=$(echo $HOSTNAME | cut -d"." -f1)
sudo sed -ie "/[[:space:]]localhost/d" /${USERD}/setup/hosts
sudo echo "127.0.0.1 $HOSTNAME $SHORTNAME" >> /${USERD}/setup/hosts
sudo mv /${USERD}/setup/hosts /etc/hosts
sudo hostnamectl set-hostname ${HOSTNAME}
sudo rm /${USERD}/setup/hostse

#Restart Services
echo -e "\e[92mRestarting Network ..." > /dev/console
systemctl restart systemd-networkd

# Restarting NTP Service to complete NTP Config
echo -e "\e[92m  Restarting Timesync ..." > /dev/console
#sudo systemctl restart systemd-timesyncd
sudo systemctl restart chronyd
sudo systemctl restart chrony

# Configure Syslog
if [[ ! -z "$SYSLOG_DESTINATION" ]];
then
	echo -e "\e[92m  Configuring Remote Syslog ..." > /dev/console
	sudo iptables -A OUTPUT -p $SYSLOG_PROTOCOL -d $SYSLOG_DESTINATION --dport $SYSLOG_PORT -j ACCEPT
	sudo cp /etc/rsyslog.conf /${USERD}/setup/rsyslog.conf
	if [[ $SYSLOG_PROTOCOL == "udp" ]];
		then
		sudo sed -i 's/#module(load="imudp")/module(load="imudp")/g' /${USERD}/setup/rsyslog.conf
		sudo sed -i 's/#input(type="imudp" port="514")/input(type="imudp" port="514")/g' /${USERD}/setup/rsyslog.conf
		SEDINPUT1='s/"imudp" port="514"/"imudp" port='
		SEDINPUT2='"'$SYSLOG_PORT'"/g'
		SEDINPUT=${SEDINPUT1}${SEDINPUT2}
		sudo sed -i "$SEDINPUT" /${USERD}/setup/rsyslog.conf
	fi
	if [[ $SYSLOG_PROTOCOL == "tcp" ]];
	then
		sudo sed -i 's/#module(load="imtcp")/module(load="imtcp")/g' /${USERD}/setup/rsyslog.conf
		sudo sed -i 's/#input(type="imtcp" port="514")/input(type="imtcp" port="514")/g' /${USERD}/setup/rsyslog.conf
		SEDINPUT1='s/"imtcp" port="514"/"imtcp" port='
		SEDINPUT2='"'$SYSLOG_PORT'"/g'
		SEDINPUT=${SEDINPUT1}${SEDINPUT2}
		sudo sed -i "$SEDINPUT" /${USERD}/setup/rsyslog.conf
	fi
	sudo chmod 0777 /${USERD}/setup/rsyslog.conf
	sudo echo "*.* @@$SYSLOG_DESTINATION:$SYSLOG_PORT" >> /${USERD}/setup/rsyslog.conf
	sudo chmod 0640 /${USERD}/setup/rsyslog.conf
	sudo cp /etc/rsyslog.conf /etc/rsyslog.conf-old
	sudo mv /${USERD}/setup/rsyslog.conf /etc/rsyslog.conf
	sudo systemctl enable rsyslog
	sudo systemctl restart rsyslog
fi
# If Syslog is not set, disable it
if [ -z "$SYSLOG_DESTINATION"  ]; 
then
	echo -e "\e[92m  Syslog not configured. Disabling Remote Syslog ..." > /dev/console
	sudo systemctl disable rsyslog
	sudo systemctl stop rsyslog
fi

# Save IPTables Config
echo -e "\e[92m  Saving IPTables Config ..." > /dev/console
sudo iptables-save > /etc/systemd/scripts/ip4save
