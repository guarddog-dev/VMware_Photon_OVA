#!/bin/bash

##Install Extra Tools
echo "  Installing Tools ..."
lastreleaseversion() { git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' "$1" | cut -d/ -f3- | tail -n1 | cut -d '^' -f 1 | cut -d 'v' -f 2; }
mkdir tools
cd tools

#Download Carvel.dev Tools
echo "   Downloading Carvel Tools ..."
sudo wget -O- https://carvel.dev/install.sh > install.sh

#Install Carvel.dev utilities
echo "   Installing Carvel Tools ..."
sudo bash install.sh > /dev/null 2>&1
echo "   Carvel Tools Installed (kapp, kbld, kctrl, kwt, imgpkg, ytt, vendir)  ..."

#Validate Carvel.dev utilities
#echo "   Validating Carvel Tool imgpkg ..."
#imgpkg version

#Install yq. The YAML, JSON, and XML Processor Utility
echo "   Installing yq utility ..."
#export VERSION=$(curl -s https://github.com/mikefarah/yq/releases/latest | cut -d '/' -f8 | cut -d '"' -f 1)
VERSION="v4.25.2"
BINARY=yq_linux_amd64
sudo wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY}.tar.gz -O - | tar xz && sudo mv ${BINARY} /usr/bin/yq > /dev/null 2>&1
#yq --version

#Download Kubecolor
echo "   Downloading Kubecolor ..."
RELEASE="0.0.20"
sudo wget https://github.com/hidetatz/kubecolor/releases/download/v${RELEASE}/kubecolor_${RELEASE}_Linux_x86_64.tar.gz
sudo tar -xvzf kubecolor_${RELEASE}_Linux_x86_64.tar.gz > /dev/null 2>&1

#Install Kubecolor
echo "   Installing Kubecolor ..."
sudo install -o root -g root -m 0755 kubecolor /usr/local/bin/kubecolor
#kubecolor
alias kubectl="kubecolor"

#Set up Kubecolor permanent Alias
echo  "   Creating Kubecolor alias ..."
cat <<EOF >> 00-aliases
#Personal Aliases
alias kubectl="kubecolor"
EOF
sudo mv 00-aliases /etc/profile.d/00-aliases.sh

#Install Kubectx
echo "   Installing Kubectx ..."
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

#Clean up Directory
#echo "   Cleaning up Directory ..."
sudo rm *

#Install Helm
echo "   Installing Helm ..."
#https://helm.sh/docs/intro/install/
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh  > /dev/null 2>&1
#helm version
rm get_helm.sh

#Install Knative Client
#https://github.com/knative/client/releases
echo "   Installing Knative (kn) Client ..."
export VERSION=$(git ls-remote --tags https://github.com/knative/client | cut -d/ -f3- | grep knative | tail -n1 | cut -d '^' -f 1 | cut -d 'v' -f 3)
curl -LO https://github.com/knative/client/releases/download/knative-v${VERSION}/kn-linux-amd64
mv kn-linux-amd64 kn
chmod +x kn
mv kn /usr/local/bin/.
#kn version

#Install Kpack Cli Client
#https://github.com/vmware-tanzu/kpack-cli/releases
echo "   Installing Kpack Cli (kp) Client ..."
export VERSION=$(git ls-remote --tags https://github.com/vmware-tanzu/kpack-cli | cut -d/ -f3- | tail -n1 | cut -d '^' -f 1  | cut -d 'v' -f 2)
curl -LO https://github.com/vmware-tanzu/kpack-cli/releases/download/v${VERSION}/kp-linux-${VERSION}
mv kp-linux-${VERSION} kp
chmod +x kp
mv kp /usr/local/bin/.
#kp version

#Install Krew
#https://krew.sigs.k8s.io/docs/user-guide/setup/install/
echo "   Installing kubectl krew ..."
(
  set -x; cd "$(mktemp -d)" &&
  OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
  ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
  KREW="krew-${OS}_${ARCH}" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
  tar zxvf "${KREW}.tar.gz" > /dev/null 2>&1 &&
  ./"${KREW}" install krew > /dev/null 2>&1
)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> /etc/profile
#kubectl krew version

#Install Tree
#https://github.com/ahmetb/kubectl-tree
echo "   Installing kubectl tree ..."
kubectl krew install tree
#kubectl tree --version

#Install ksniff
#https://github.com/eldadru/ksniff
echo "   Installing kubectl sniff (ksniff) ..."
kubectl krew install sniff

#Install TCP Dump
#https://vmware.github.io/photon/assets/files/html/3.0/photon_admin/installing-the-packages-for-tcpdump-and-netcat-with-tdnf.html
echo "   Installing TCPDump ..."
tdnf -y install tcpdump > /dev/null 2>&1

#Install netcat
#https://vmware.github.io/photon/assets/files/html/3.0/photon_admin/installing-the-packages-for-tcpdump-and-netcat-with-tdnf.html
echo "   Installing Netcat ..."
tdnf -y install netcat > /dev/null 2>&1

#Install jq
#https://vmware.github.io/photon/assets/files/html/3.0/photon_admin/installing-the-packages-for-tcpdump-and-netcat-with-tdnf.html
echo "   Installing jq ..."
tdnf -y install jq > /dev/null 2>&1

#Install Kustomize
#https://kustomize.io/
echo "   Installing kustomize ..."
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash > /dev/null 2>&1
chmod +x ./kustomize
sudo mv ./kustomize /usr/bin/kustomize

#Install KIND
#https://kind.sigs.k8s.io/docs/user/quick-start/#installing-with-a-package-manager
echo "   Installing kind ..."
RELEASEURL="https://github.com/kubernetes-sigs/kind"
VERSION=$(lastreleaseversion ${RELEASEURL})
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v${VERSION}/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/bin/kind

#Install jam
echo "   Installing jam ..."
tdnf install -y go > /dev/null 2>&1
git clone https://github.com/paketo-buildpacks/jam > /dev/null 2>&1
cd jam
go build > /dev/null 2>&1
mv jam /usr/bin/jam
cd ..
rm -rf jam
rm -rf go

#Install go-md2man
echo "   Installing go-md2man ..."
git clone https://github.com/cpuguy83/go-md2man > /dev/null 2>&1
cd go-md2man
make > /dev/null 2>&1
mv ./bin/go-md2man /usr/bin/go-md2man
cd ..
rm -rf go-md2man
rm -rf go

#Install skopeo
echo "   Installing skopeo ..."
tdnf install -y go > /dev/null 2>&1
tdnf install -y build-essential > /dev/null 2>&1
tdnf install -y gpgme-devel > /dev/null 2>&1
tdnf install -y device-mapper-devel > /dev/null 2>&1
git clone https://github.com/containers/skopeo > /dev/null 2>&1
cd skopeo
make > /dev/null 2>&1
mv ./bin/skopeo /usr/bin/skopeo
cd ..
rm -rf skopeo
rm -rf go

#Remove Utilities
echo "   Removing Temporary Packages ..."
tdnf remove -y build-essential > /dev/null 2>&1
tdnf remove -y gpgme-devel > /dev/null 2>&1
tdnf remove -y device-mapper-devel > /dev/null 2>&1
tdnf remove -y go > /dev/null 2>&1
rm -rf go
rm -rf /root/go

#Clean up temp tools directory
cd ..
rmdir tools

