##General Scripts to prep OS

# Set Versions
USERD="root"

# Disable IPv6
echo '> Disable IPv6'
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf

# Install latest Updates
echo '> Applying latest Updates...'
sudo sed -i 's/dl.bintray.com\/vmware/packages.vmware.com\/photon\/$releasever/g' /etc/yum.repos.d/*.repo
tdnf -y update photon-repos
tdnf clean all
tdnf makecache
tdnf -y update

#Install Additional Packages
echo '> Installing Additional Packages...'
tdnf install -y \
  logrotate \
  wget \
  sudo \
  unzip \
  tar \
  nano \
  curl \
  parted \
  git \
  chrony \
  net-tools \
  bindutils \
  dmidecode \
  rsyslog \
  audit
  
#Enable Audit Daemon Service
sudo systemctl enable auditd.service
sudo systemctl start auditd.service
  
#Validate that root is a sudoer
echo '> Validating root is a sudoer...'
usermod -aG sudo root

#Create directory for setup scripts
echo '> Creating directory for setup/startup scripts...'
mkdir -p /${USERD}/setup

#create standard user
#echo '> Creating User stduser...'
#useradd -m -g sudo stduser
#usermod -aG docker stduser
#STD_PASSWORD="VMware123!"
#echo "stduser:${STD_PASSWORD}" | /usr/sbin/chpasswd
#sudo mkdir /tanzu
#sudo chown stduser: /tanzu
