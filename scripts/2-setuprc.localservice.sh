#!/bin/bash
# Set Boot Screen Info
# Reference https://marsown.com/wordpress/how-to-enable-etc-rc-local-with-systemd-on-ubuntu-20-04/
# reference2 https://www.cyberciti.biz/faq/howto-change-login-message/

# Set Versions
USERD="root"

#Enable RC.Local Service
echo '> Setting up rc-local Service...'
systemctl status rc-local.service
systemctl enable rc-local.service

#Create rc-local
echo '> Creating rc-local.service file...'
cd ~
touch rc-local
sudo echo '[Unit]' >> rc-local
sudo echo ' Description=Provides Start Up Custom Scripting' >> rc-local
sudo echo ' ConditionPathExists=/etc/rc.local'  >> rc-local
sudo echo ' Wants=network-online.target'  >> rc-local
sudo echo ' After=network.target network-online.target vmtoolsd.service'  >> rc-local
sudo echo ' ' >> rc-local
sudo echo '[Service]' >> rc-local
sudo echo ' Type=forking' >> rc-local
sudo echo ' ExecStart=/etc/rc.local start' >> rc-local
sudo echo ' TimeoutSec=0' >> rc-local
sudo echo ' StandardOutput=tty' >> rc-local
sudo echo ' RemainAfterExit=yes' >> rc-local
sudo echo ' SysVStartPriority=99' >> rc-local
sudo echo ' Environment=HOME=/root' >> rc-local
sudo echo ' ' >> rc-local
sudo echo '[Install]' >> rc-local
sudo echo ' WantedBy=multi-user.target' >> rc-local
sudo mv rc-local rc-local.service
#less rc-local.service
sudo mv rc-local.service /etc/systemd/system/rc-local.service

#Create rc.local
#echo '> Creating rc.local file...'
cd ~
touch rclocal
sudo echo '#!/bin/sh' > rclocal
sudo echo '  ' >> rclocal
sudo echo '#Set User Account' >> rclocal
sudo echo 'USERD=root' >> rclocal
sudo echo '#Configure Issues File for Boot Info' >> rclocal
sudo echo 'sudo chown $USERD:root /etc/issue' >> rclocal
sudo echo 'sudo chmod 644 /etc/issue' >> rclocal
sudo echo 'PREFIX="Welcome to guardDog virtual unit "vFido""' >> rclocal
sudo echo 'BOOTTIME=$(date)' >> rclocal
sudo echo 'HOSTM=$(hostname)' >> rclocal
sudo echo 'IFACE=eth0'  >> rclocal
sudo echo 'IPADDRS=$(ip a s $IFACE | egrep -o "inet [0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | cut -d" " -f2)'  >> rclocal
sudo echo 'read MAC </sys/class/net/$IFACE/address'  >> rclocal
#https://kb.vmware.com/s/article/53609
sudo echo 'UUID=$(get_uuid)'  >> rclocal
sudo echo 'sudo echo "$PREFIX
Boot Time: $BOOTTIME
Host Name: $HOSTM
IP: $IPADDRS
MAC Address: $MAC
UUID: $UUID" > /etc/issue'  >> rclocal
sudo echo 'sudo chown 0 /etc/issue' >> rclocal
sudo echo '  ' >> rclocal
sudo echo '#Set OS Customizations' >> rclocal
sudo echo 'if [ -e /${USERD}/ran_customization ]; then' >> rclocal
sudo echo '    exit' >> rclocal
sudo echo 'else' >> rclocal
sudo echo '    /${USERD}/setup/setup.sh &> /var/log/bootstrap.log' >> rclocal
sudo echo 'fi' >> rclocal

#less rclocal
sudo mv rclocal rc.local
sudo mv rc.local /etc/rc.local
sudo chmod u+x /etc/rc.local
#less /etc/rc.local

#sudo systemctl status rc-local.service
sudo touch /${USERD}/ran_customization

#Enable rc-local Service
echo '> Enable rc.local Service...'
sudo systemctl daemon-reload
sudo systemctl enable --now rc-local.service
