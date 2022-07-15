#!/bin/bash
# Setup Cluster and MetalLb
echo '  Preparing for MetalLb ...'

# Versions
#Internal Domain name
DOMAIN_NAME=$(hostname -d)
#Tanzu/Kubernetes cluster name
CLUSTER_NAME='local-cluster'
#Control Plane Name
CONTROL_PLANE="$CLUSTER_NAME"-control-plane
#Location Name
USERD=root
# Github Variables for YAML files
#REPO="https://github.com/guarddog-dev"
#REPONAME="VMware_Photon_OVA"
#REPOFOLDER="yaml"

# Find if variable exists
echo '   Checking if Kubernetes VIP exists ...'
ETH_IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')

# Disable DNS Resolver on system
echo '   Disabling system-d resolved service ...'
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved

# Create Unmanaged Cluster
echo '   Creating Unmanaged Cluster ...'
tanzu um create ${CLUSTER_NAME} -c calico -p 80:80 -p 443:443 -p 53:53 -p 67:67

# Valideate Cluster is ready
echo "   Validating Unmanaged Cluster $CLUSTER_NAME is Ready ..."
STATUS=NotReady
while [[ $STATUS != "Ready" ]]
do
echo "    Tanzu Cluster $CLUSTER_NAME Status - NotReady"
sleep 10s
STATUS=$(kubectl get nodes -n $CONTROL_PLANE | tail -n +2 | awk '{print $2}')
done
echo "    Tanzu Cluster $CLUSTER_NAME Status - Ready"
kubectl get nodes,po -A
sleep 20s

## Install MetalLB (load-balancer)
METALLBVERSION=0.12.1
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLBVERSION}/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLBVERSION}/manifests/metallb.yaml
kubectl -n metallb-system get all

## Set Cluster IPs
CLUSTERIP=$(kubectl get nodes -n local-cluster-control-plane -o yaml | grep "address: 1" | cut -d ":" -f 2 | cut -d " " -f 2)
#BASEIP=$(echo $ETH_IP | cut -d "." -f1-3)
BASEIP=$(echo $CLUSTERIP | cut -d "." -f1-3)
BEGINIP=${BASEIP}.201
ENDIP=${BASEIP}.210
cat <<EOF > metallb.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - ${BEGINIP}-${ENDIP}
EOF
kubectl create -f metallb.yaml
kubectl get configmap -n metallb-system config -o yaml

# Echo Completion
sleep 10s
#IP_ADDRESS=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
clear
echo "   MetalLb pod deployed ..."
sleep 60s
