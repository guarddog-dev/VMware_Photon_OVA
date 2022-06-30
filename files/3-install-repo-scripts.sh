#!/bin/bash

#set -euo pipefail

# Run Repo Script post install

# Variables
REPO="https://github.com/guarddog-dev"
REPONAME="VMware_Photon_OVA"
FOLDER="post-deploy-scripts"

#Download Repo Folder
echo "\e[92m  Downloading Github Repo ${REPO}/${REPONAME} - Folder: ${FOLDER}"
git clone --filter=blob:none --sparse ${REPO}/${REPONAME}
cd ${REPONAME}
git sparse-checkout init --cone
git sparse-checkout add ${FOLDER}
cd ${FOLDER}
CURRENTPATH=$(pwd)

# Starting Automation
echo -e "\e[92m  Running Repo Scripting ..." > /dev/console
for f in *.sh;do 
  bash "$f"
done

#Cleanup
echo "\e[92m  Cleaning up Github Repo Download ..." > /dev/console
cd ${CURRENTPATH}
rm -rf *
cd ..
rmdir --ignore-fail-on-non-empty *
rm -rf .*
rm -rf *
cd ..
rmdir ${REPONAME}

