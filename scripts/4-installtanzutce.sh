#####Install Tanzu Community Edition directly (without Homebrew)
##Based on Tanzu 0.12.1
echo '> Downloading Tanzu Community Edition...'

# Set Versions
tanzutce_version="v0.12.1"

#Download Tanzue Community Edition
#export RELEASE=$(curl -s https://github.com/vmware-tanzu/community-edition/releases/latest | grep tag/ | cut -d '/' -f 8 | cut -d '"' -f 1)
echo "> Downloading Release Version $tanzutce_version..."
mkdir /tanzu
cd /tanzu
wget https://github.com/vmware-tanzu/community-edition/releases/download/$tanzutce_version/tce-linux-amd64-$tanzutce_version.tar.gz

#Extract Tanzu Installer
echo "> Extracting Tanzu Community Edition: Build $tanzutce_version..."
sudo tar xzvf tce-linux-amd64-${tanzutce_version}.tar.gz
#sleep 20s

#Install Tanzu
echo "> Installing Tanzu Community Edition Binary: Build $tanzutce_version..."
cd /tanzu/tce-linux-amd64-${tanzutce_version}
ALLOW_INSTALL_AS_ROOT=true ./install.sh

#Validate Version
echo "> Validating Tanzu Community Edition Binary..."
tanzu version

##Cleanup Tanzu gz file
echo "> Cleaning up tce-linux-amd64-$tanzutce_version.tar.gz file..."
sudo rm /tanzu/tce-linux-amd64-$tanzutce_version.tar.gz

#Set up Auto Completion Permanently for Tanzu
#Found bug. Created Bug report: https://github.com/vmware-tanzu/community-edition/issues/3758
echo -e '> Setting up Auto Complete permanently for Tanzu...'
source <(tanzu completion bash)
echo 'source /usr/share/bash-completion/bash_completion' >>~/.bashrc
mkdir /etc/bash_completion.d
/usr/local/bin/tanzu completion bash >/etc/bash_completion.d/tanzu

#Open Ports
echo -e '> Opening standard Tanzu Ports...'
sudo iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp -m tcp --dport 8080 -j ACCEPT
sudo iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
sudo iptables-save > /etc/systemd/scripts/ip4save
