#!/bin/bash
# Install Relax-and-Recover

# Install prereqs
echo ' Installing Relax-and-Recover prereqs ...'
sudo tdnf install -y \
make \
mingetty \
parted \
diffutils \
kbd \
binutils \
git

# Install prereqs
echo '   Installing Relax-and-Recover (rear) ...'
git clone https://github.com/rear/rear.git
cd rear
make install

# Install prereqs
echo '   Review rear version ...'
rear --version

# Create rear /etc/rear/site.conf file
cat <<EOF > /etc/rear/site.conf
# Site config file for Relax and Recover (ReaR)

BACKUP=NETFS
OUTPUT=ISO
ISO_DEFAULT="automatic"

# Save to ISO
BACKUP_URL="iso:///backup"
OUTPUT_URL=null

# Save to NFS and boot from small ISO
# BACKUP_URL=nfs://172.26.4.30/mnt/FREENAS01/exports

# Notes
# Place file in /etc/rear/site.conf
EOF

# Clean up git clone
echo '   Clearning Up Rear Install ...'
cd ..
rm -rf rear
