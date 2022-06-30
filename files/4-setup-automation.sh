#!/bin/bash

# Setup Networking

# Set user account that will configure OS post OVA deployment
USERD=root

#set -euo pipefail

# Starting Automation
echo -e "\e[92m  Starting Script $AUTOMATION_SELECTION ..." > /dev/console
#cd /{USERD}/automation
SCRIPT_NAME="$AUTOMATION_SELECTION.sh"
. /${USERD}/automation/${SCRIPT_NAME} | tee -a /${USERD}/automation/automation.txt > /dev/console

