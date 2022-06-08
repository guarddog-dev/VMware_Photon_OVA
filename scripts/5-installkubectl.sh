#!/bin/bash
##Setup kubectl

# Set Versions
RELEASE="v1.22.7"

#Install kubectl
echo '> Installing kubectl utility...'
curl -LO https://dl.k8s.io/release/${RELEASE}/bin/linux/amd64/kubectl
#curl -L "https://dl.k8s.io/release/$RELEASE/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
#chmod +x /usr/local/bin/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kube*

#Disable Swap
echo '> Disabling Swap...'
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a
rm /swap.img
swapon --show

##Set IPTables to see bridged Traffic
#Reference: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
echo '> Setting IPTables to be bridged for Kubernetes Traffic...'
cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

#Enable Forwarding from Docker Containers
echo '> Enabling Forwarding from Docker Containers...'
sysctl net.ipv4.conf.all.forwarding=1
iptables -P FORWARD ACCEPT

#Get Client Info
echo '> Getting kubectl version...'
kubectl version --short

#Set up Auto Completion Permanently for Kubectl
echo -e '> Setting up Auto Complete permanently for Kubectl...'
source <(kubectl completion bash)
#kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
