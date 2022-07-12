#!/bin/bash
# Setup Pi-Hole Using Metallb
echo '  Preparing for Pi-Hole ...'

# Versions
#Version of MetalLB Version to install
METALLBVERSION=0.12.1
#Internal Domain name
DOMAIN_NAME=$(hostname -d)
#Internal DNS Entry to that resolves to the Pi-hole fqdn - you must make this DNS Entry
PIHOLE_FQDN="pihole.${DOMAIN_NAME}"
#Pihole Admin Password
PIHOLE_ADMIN_PASSWORD='VMware12345!'
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

## Install Pi-Hole
echo "   Adding helm repo mojo2600 for pihole deployment ..."
#Reference https://greg.jeanmart.me/2020/04/13/self-host-pi-hole-on-kubernetes-and-block-ad/
helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/
helm repo update

# Create Namespace pihole
echo "   Creating Namespace pihole ..."
kubectl create namespace pihole

# Create a secret to store Pi-Hole admin password
echo "   Creating secret (password) for pihole admin ..."
kubectl create secret generic pihole-secret \
  --from-literal="password=$PIHOLE_ADMIN_PASSWORD" \
  --namespace pihole

# List secret password
echo "   Listing pihole admin secret (password) ..."
kubectl get secret pihole-secret --namespace pihole -o jsonpath='{.data.password}' | base64 --decode
echo " "

# Get Timezone from OVA
TZ=$(timedatectl status | grep "Time zone" | cut -d ":" -f 2 | cut -d " " -f 2)
echo "   Applying system timezone $TZ for pihole ..."

# Install Pihole
echo "   Using helm to install pihole ..."
helm install pihole mojo2600/pihole \
  --namespace pihole \
  --replace \
  --set image.tag="latest" \
  --set extraEnvVars.TZ="${TZ}" \
  --set hostNetwork="true" \
  --set serviceDns.type="ClusterIP" \
  --set serviceDhcp.type="ClusterIP" \
  --set serviceWeb.type="ClusterIP" \
  --set virtualHost="pihole" \
  --set ingress.enabled="false" \
  --set ingress.hosts[0]="$(hostname -d)" \
  --set persistentVolumeClaim.enabled="true" \
  --set admin.existingSecret="pihole-secret" \
  --set doh.enabled="false" \
  --set hostname="pihole" \
  --set dnsHostPort.enabled="true" \
  --set serviceDns.mixedService="true" \
  --set subdomain="$(hostname -d)"

# Validate that pihole pod is ready
echo "   Validate that pihole pod is ready ..."
PIHOLEPOD=$(kubectl get po -n pihole | grep pihole | cut -d " " -f 1)
while [[ $(kubectl get po -n pihole $PIHOLEPOD -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for pod $PIHOLEPOD to be ready" && sleep 1; done
echo "   Pod $PIHOLEPOD is now ready ..."

# Show pihole pod info
echo "   Pihole pod info: ..."
kubectl get pods -n pihole -o wide
kubectl get services -n pihole -o wide
kubectl describe services -n pihole
kubectl get ingress -n pihole -A
#kubectl logs ${PIHOLEPOD} -n pihole --all-containers

# Setup Pihole for local DNS resolution
#echo "   Setting Pihole DNS resolution for local PhotonOS ..."
#sudo unlink /etc/resolv.conf
#NODE_IP=$(kubectl get node ${CONTROL_PLANE} -o yaml | grep 'projectcalico.org/IPv4Address:' | cut -d " " -f 6 | cut -d "/" -f 1)
#sudo echo "nameserver ${NODE_IP}" | sudo tee /etc/resolv.conf
#sudo systemctl enable systemd-resolved
#sudo systemctl start systemd-resolved

# Echo Completion
sleep 10s
clear
echo "   Pihole pod deployed ..."
echo "   You can access Pihole by going to:"
echo "                                      http://$PIHOLE_FQDN"
echo "   Login: admin"
echo "   Password: $PIHOLE_ADMIN_PASSWORD"
echo " "
echo "   Note: You must make a DNS or HOST File entry for $PIHOLE_FQDN to be able to be accessed"
sleep 60s
