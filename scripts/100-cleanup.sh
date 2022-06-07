#!/bin/bash
# cleanup everything we can to make the OVA as small as possible

# Set Versions
USERD="root"
tanzutce_version="v0.12.1"


# Clean up Tanzu Installation Binaries
echo '> Cleaning up Tanzu Installation Binaries ...'
#export RELEASE=$(curl -s https://github.com/vmware-tanzu/community-edition/releases/latest | grep tag/ | cut -d '/' -f 8 | cut -d '"' -f 1)
sudo rm -r /tanzu/tce-linux-amd64-${tanzutce_version}/*
sudo rmdir /tanzu/tce-linux-amd64-${tanzutce_version}

# Update
echo '> Updating all Binaries ...'
tdnf -y update photon-repos
tdnf clean all
tdnf makecache
tdnf -y update

# Cleans apt-get
echo '> Clearing tdnf cache...'
tdnf clean all

# Clean Audit Logs
echo '> Cleaning all audit logs ...'
if [ -f /var/log/audit/audit.log ]; then
sudo cat /dev/null > /var/log/audit/audit.log
fi
if [ -f /var/log/wtmp ]; then
sudo cat /dev/null > /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
sudo cat /dev/null > /var/log/lastlog
fi

# Clean journalctl logs
echo '> Cleaning all journalctl logs ...'
journalctl --disk-usage
sudo journalctl --vacuum-time=1m
journalctl --disk-usage

# Sets hostname to localhost.
echo '> Setting hostname to localhost ...'
sudo cat /dev/null > /etc/hostname
sudo hostnamectl set-hostname localhost

# Cleans the machine-id.
echo '> Cleaning the machine-id ...'
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Clearing History File
echo '> Clearing History File...'
sudo unset HISTFILE && sudo history -c && sudo rm -fr /${USERD}/.bash_history

# Clean Log Files
echo '> Removing Log files...'
sudo cat /dev/null > /var/log/wtmp 2>/dev/null
sudo logrotate -f /etc/logrotate.conf 2>/dev/null
sudo find /var/log -type f -delete
sudo rm -rf /var/log/journal/*
sudo rm -f /var/lib/dhcp/*

# Fix Configuration issues post CIS Remediation
# Fix password pwquality.conf issues
echo '> Fixing Ubuntu configuration issues post CIS Remediation...'
sudo chmod u=rw,g=r,o=r /etc/security/pwquality.conf
sudo mv /etc/security/pwquality.conf /${USERD}/setup/pwquality.conf
sudo apt-get install libpam-pwquality -y
sudo mv /${USERD}/setup/pwquality.conf /etc/security/pwquality.conf
# fix audit permissions
#sudo chmod 0655 /etc/audit
#sudo chmod 0655 /etc/audit/*
# postfix_network_listening_disabled
sudo sed -i "s/inet_interfaces = all/inet_interfaces = loopback-only/g" /etc/postfix/main.cf
# fix audit permissions file access
#sudo chmod 0655 /etc/audit/*
# fix shadow file permissions access
sudo chmod 0640 /etc/shadow
# fix shadow backup file permissions access
sudo chmod 0640 /etc/shadow-
# set root password (required for single user mode access)
#THE_ROOT_PASSWORD='Gu@RdD0gRo^k$!'
#echo "root:${THE_ROOT_PASSWORD}" | sudo /usr/sbin/chpasswd
# set root account timeouts
#sudo chage -M 5 root
#sudo chage -m 1 root
# disable root ssh login - only required since root has to be an active account - not a CIS requirement
#sudo sed -i "s#root:/bin/bash#root:/sbin/nologin#g" /etc/passwd
# disable postfix - has_nonlocal_mta
sudo update-rc.d postfix disable

#Set root password attributes
echo '> Setting administrator password attributes post CIS Remediation...'
sudo chage -m 0 root

#List root password attributes
echo '> Listing administrator password attributes post CIS Remediation...'
sudo chage -l root

# Zero out the free space to save space in the final image
echo '> Zeroing device to make space (this will take a while)...'
# Primary Drive
dd if=/dev/zero of=/EMPTY bs=1M || true; sync; sleep 1; sync
rm -f /EMPTY; sync; sleep 1; sync

# Listing storage space
echo '> Listing Storage Space...'
df -h
echo ' '

# Set random password
echo '> Setting random password...'
RANDOM_PASSWORD=$(< /dev/urandom tr -dc '_A-Z-a-z-0-9!@#$%*()-+' | head -c${1:-32};echo;)
echo "${USERD}:${RANDOM_PASSWORD}" | sudo /usr/sbin/chpasswd
#tail -n 10 /var/log/auth.log
#Note: Password has been already used will show, but doing tail shows that the password was changed correctly.

# Clear Password History
echo '> Clearing Password History...'
sudo echo "" > /tmp/opasswd
sudo mv /tmp/opasswd /etc/security/opasswd
sudo rm /etc/security/opasswd.old

# Clear History file
echo '> Clearing History File...'
unset HISTFILE && history -c && rm -fr /root/.bash_history

# Cleans SSH keys.
echo '> Cleaning SSH keys ...'
sudo rm -f /etc/ssh/ssh_host_*
sudo systemctl disable ssh

# Enable RC.Local Service
echo '> Enable rc-local Service...'
sudo systemctl enable rc-local.service
sudo rm /${USERD}/ran_customization

# Completed
echo '> Done!!!'
sudo -S shutdown -P
