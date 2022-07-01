#!/bin/bash

#set -euo pipefail

# Run Repo Script post install

# Variables
REPO="https://github.com/guarddog-dev"
REPONAME="VMware_Photon_OVA"
REPOFOLDER="post-deploy-scripts"

#Download Repo Folder
echo -e "\e[92m  Downloading Repo Folder ..." > /dev/console
git clone --filter=blob:none --sparse ${REPO}/${REPONAME}
cd ${REPONAME}
git sparse-checkout init --cone
git sparse-checkout add ${REPOFOLDER}
cd ${REPOFOLDER}
CURRENTPATH=$(pwd)
chmod +x *.sh

# Starting Automation
echo -e "\e[92m  Running Repo Scripting ..." > /dev/console
for f in *.sh;do
  #run script
  bash "$f" > /dev/console
  #go back to working directory
  cd ${CURRENTPATH}
  #cleanup
  #sudo rm -v !(*.sh)
done

#Cleanup
echo -e "\e[92m  Cleaning up Repo Download ..." > /dev/console
cd ${CURRENTPATH}
rm -rf *
cd ..
rmdir --ignore-fail-on-non-empty *
rm -rf .*
rm -rf *
cd ..
rmdir ${REPONAME}

