#!/bin/bash
# harden appliance
echo '> Hardening Appliance...'

# Set SSHD Ciphers
sudo echo "ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config

# Set SSHD Banner
sudo echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
sudo echo "GuardDog AI Systems. Authorized uses only. All activity will be monitored and reported." >> /etc/issue.net

# Set SSHD Client Active Count Max
sudo sed -i "s/ClientAliveCountMax 2/ClientAliveCountMax 0/g" /etc/ssh/sshd_config

# Set Max Logins
sudo echo '* Â  Â  Â  Â  Â  Â  Â hard Â  Â maxlogins Â  Â  Â 10' >> /etc/security/limits.conf

# Set TCP Settings
sudo echo "net.ipv4.tcp_syncookies=1" >> /etc/sysctl.conf

# Set SSHd syslogfacility
sudo sed -i "s/#SyslogFacility AUTH/SyslogFacility AUTHPRIV/g" /etc/ssh/sshd_config
sudo sed -i "s/#MaxAuthTries 6/MaxAuthTries 2/g" /etc/ssh/sshd_config

# Set Authpriv in rsyslog
sudo echo "#authpriv" >> /etc/rsyslog.conf
sudo echo "authpriv.*			/var/log/audit/sshinfo.log" >> /etc/rsyslog.conf

# set system-auth
# causes issue with login
#sudo echo "auth Â  Â required Â  Â  Â  Â pam_tally2.so file=/var/log/tallylog deny=3 onerr=fail even_deny_root unlock_time=86400 root_unlock_time=300" >> /etc/pam.d/system-auth

# Set tmout in profile.d
sudo cat > /etc/profile.d/tmout.sh  << EOF
TMOUT=900
readonly TMOUT 
export TMOUT
mesg n 2>/dev/null
EOF

# Enable Audit Settings
sudo cat > /etc/audit/rules.d/audit.STIG.rules  << EOF
-w /etc/passwd -p wa -k passwd
-w /etc/shadow -p wa -k shadow
-w /etc/group -p wa -k group
-w /etc/gshadow -p wa -k gshadow
-w /usr/sbin/userdel -p x -k userdel
-w /usr/sbin/groupdel -p x -k groupdel
-a always,exit -F path=<setuid_path> -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged
EOF

# Set Password requirements
sudo sed -i "s/PASS_MAX_DAYS    90/PASS_MAX_DAYS    365/g" /etc/login.defs
sudo sed -i "s/PASS_MIN_DAYS   0/PASS_MIN_DAYS   1/g" /etc/login.defs

# Set Password Complexity
sudo cat >> /etc/security/pwquality.conf << EOF

# Per CCE: Set dcredit = -1 in /etc/security/pwquality.conf
dcredit = -1

# Per CCE: Set lcredit = -1 in /etc/security/pwquality.conf
lcredit = -1

# Per CCE: Set minclass = 4 in /etc/security/pwquality.conf
minclass = 4

# Per CCE: Set minlen = 14 in /etc/security/pwquality.conf
minlen = 14

# Per CCE: Set ocredit = -1 in /etc/security/pwquality.conf
ocredit = -1

# Per CCE: Set ucredit = -1 in /etc/security/pwquality.conf
ucredit = -1
EOF

# Edit Audit D settings
sudo sed -i "s/max_log_file_action = ROTATE/max_log_file_action = IGNORE/g" /etc/audit/auditd.conf

# Set fail delay on login defs
sudo sed -i 's/# FAIL_DELAY/FAIL_DELAY/g' /etc/login.defs



