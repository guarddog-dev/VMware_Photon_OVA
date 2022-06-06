#####Install Tanzu Community Edition directly (without Homebrew)
##Based on Tanzu 0.12.1
echo '> Downloading Tanzu Community Edition...'

# Set Versions
USERD="root"
tanzutce_version="v0.12.1"
STD_PASSWORD="VMware123!"

#Change to Tanzu install directory
cd /tanzu/tce-linux-amd64-${tanzutce_version}

##Install Tanzu
echo "> Installing Tanzu Community Edition Binary: Build $tanzutce_version..."
./install.sh

##Cleanup Tanzu gz file
echo "> Cleaning up tce-linux-amd64-$tanzutce_version.tar.gz file..."
sudo rm /tanzu/tce-linux-amd64-$tanzutce_version.tar.gz

#Set up Auto Completion Permanently for Tanzu
#Found bug. Created Bug report: https://github.com/vmware-tanzu/community-edition/issues/3758
echo -e '> Setting up Auto Complete permanently for Tanzu...'
source <(tanzu completion bash)
