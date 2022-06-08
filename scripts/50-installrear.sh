#!/bin/bash
# Install Relax-and-Recover

# Install prereqs
echo '> Installing Relax-and-Recover prereqs...'
sudo tdnf install -y \
make \
mingetty \
parted \
diffutils \
kbd \
binutils \
git \
parted

# Install prereqs
echo '> Installing Relax-and-Recover (rear)...'
git clone https://github.com/rear/rear.git
cd rear
make install

# Install prereqs
echo '> Review rear version...'
rear --version

# Clean up git clone
echo '> Clearning Up Rear Install...'
cd ~
rm -rf rear
