#!/bin/bash

#example ./resize.sh /dev/sda 3

echo "Resizing Partition ${2} on ${1} with new end ${3}"
echo 1 > /sys/class/block/sda/device/rescan
PVERSION=$(parted --version | grep 'GNU parted' | cut -d ' ' -f 4)

if [[ $PVERSION == "3.3" ]]; then
echo 'Parted Version 3.3 Detected'
parted "${1}" ---pretend-input-tty <<EOF
resizepart
Fix
${2}
${3}
Yes
100%
quit
EOF

clear

parted "${1}" ---pretend-input-tty <<EOF
resizepart
${2}
${3}
Yes
100%
quit
EOF

clear

echo "Resizing File System on Partition ${2} on disk ${1}"
resize2fs ${1}${2}
#echo "Listing File System Post Resize"
#df -h
fi
