##Setup Kubelet/kubectl

# Set Versions
RELEASE="1.23.6-00"
ARCH="amd64"

#Install kubelet,kubeadm,kubectl
echo '> Installing Kubelet Service + kubectl and kubeadm utilities...'
#curl -LO "https://storage.googleapis.com/kubernetes-release/release/${RELEASE}/bin/linux/${ARCH}/{kubeadm,kubelet,kubectl}"
curl -LO "https://dl.k8s.io/release/${RELEASE}/bin/linux/${ARCH}/{kubectl}"
#chmod +x {kubeadm,kubelet,kubectl}
#install -o root -g root -m 0755 kubeadm /usr/local/bin/kubeadm
#install -o root -g root -m 0755 kubelet /usr/local/bin/kubelet
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kube*

#Disable Swap
echo '> Disabling Swap...'
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a
rm /swap.img
swapon --show

#####Modify Kubelet service to use same Cgroup driver
#Reference https://stackoverflow.com/questions/43794169/docker-change-cgroup-driver-to-systemd
#sed -i 's% --kubeconfig=/etc/kubernetes/kubelet.conf% --kubeconfig=/etc/kubernetes/kubelet.conf --cgroup-driver=cgroupfs%g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
#####

#Enable kubelet service
#echo '> Enabling and Starting Kubelet Service...'
#systemctl enable kubelet
#systemctl start kubelet

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

#Restart services
#echo '> Restarting services...'
#systemctl enable --now kubelet
#systemctl daemon-reload && systemctl restart docker #&& systemctl restart kubelet

#Get Client Info
echo '> Getting kubectl version...'
kubectl version --client

#Set up Auto Completion Permanently for Kubectl
echo -e '> Setting up Auto Complete permanently for Kubectl...'
source <(kubectl completion bash)
#kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
