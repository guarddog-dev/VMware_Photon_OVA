#####Install Tanzu Community Edition directly (without Homebrew)
##Based on Tanzu 0.12.1
echo '> Downloading Tanzu Community Edition...'

# Set Versions
USERD="root"
STD_USER="stduser"
tanzutce_version="v0.12.1"

#Download Tanzue Community Edition
#export RELEASE=$(curl -s https://github.com/vmware-tanzu/community-edition/releases/latest | grep tag/ | cut -d '/' -f 8 | cut -d '"' -f 1)
echo "> Downloading Release Version $tanzutce_version..."
cd /tanzu
wget https://github.com/vmware-tanzu/community-edition/releases/download/$tanzutce_version/tce-linux-amd64-$tanzutce_version.tar.gz

#Extract Tanzu Installer
echo "> Extracting Tanzu Community Edition: Build $tanzutce_version..."
sudo tar xzvf tce-linux-amd64-${tanzutce_version}.tar.gz

#Workaround
echo "> Pre-Installing Tanzu Community Edition Binary: Build $tanzutce_version..."
sudo install /tanzu/tce-linux-amd64-${tanzutce_version}/tanzu /usr/local/bin
