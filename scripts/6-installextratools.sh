##Install Extra Tools

#Download Carvel.dev Tools
echo "> Downloading Carvel Tools..."
sudo wget -O- https://carvel.dev/install.sh > install.sh

#Install Carvel.dev utilities
echo "> Installing Carvel Tools..."
sudo bash install.sh

#Validate Carvel.dev utilities
echo "> Validating Carvel Tool imgpkg..."
imgpkg version

#Install yq. The YAML, JSON, and XML Processor Utility
echo "> Installing yq. The YAML, JSON, and XML Processor Utility..."
#export VERSION=$(curl -s https://github.com/mikefarah/yq/releases/latest | cut -d '/' -f8 | cut -d '"' -f 1)
VERSION="v4.25.2"
BINARY=yq_linux_amd64
sudo wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz -O - | tar xz && sudo mv ${BINARY} /usr/bin/yq
yq --version

#Download Kubecolor
echo "> Downloading Kubecolor..."
RELEASE="0.0.20"
sudo wget https://github.com/hidetatz/kubecolor/releases/download/v${RELEASE}/kubecolor_${RELEASE}_Linux_x86_64.tar.gz
sudo tar -xvzf kubecolor_${RELEASE}_Linux_x86_64.tar.gz

#Install Kubecolor
echo "> Installing Kubecolor..."
sudo install -o root -g root -m 0755 kubecolor /usr/local/bin/kubecolor
kubecolor
alias kubectl="kubecolor"

#Install Kubectx
echo "> Installing Kubectx..."
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

#Clean up Directory
echo "> Cleaning up Directory..."
sudo rm *

#Set up Kubecolor permanent Alias
echo  '> Setting up Kubecolor permanent alias...'
cat <<EOF >> 00-aliases
#Personal Aliases
alias kubectl="kubecolor"
EOF
sudo mv 00-aliases /etc/profile.d/00-aliases.sh

#Install Helm
echo '> Installing Helm...'
#https://helm.sh/docs/intro/install/
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm version
rm get_helm.sh
