#!/bin/bash
# Install Relax-and-Recover

# Install prereqs
echo "  Installing Relax-and-Recover (rear) ..."
echo '   Installing (rear) prereqs ...'
sudo tdnf install -y \
make \
mingetty \
parted \
diffutils \
kbd \
binutils \
git  > /dev/null 2>&1

# Install prereqs
echo '   Installing (rear) ...'
git clone https://github.com/rear/rear.git
cd rear
make install  > /dev/null 2>&1

# Install prereqs
#echo '   Review rear version ...'
#rear --version

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
# BACKUP_URL=nfs://<IP_ADDRESS_HERE>/mnt/FREENAS01/exports

# Notes
# Place file in /etc/rear/site.conf
EOF

# Clean up git clone
echo '   Cleaning Up Rear Install ...'
cd ..
rm -rf rear
