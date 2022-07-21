#!/bin/bash
# Setup Tdarr
echo '  Preparing for Tdarr ...'
# Reference: https://artifacthub.io/packages/helm/k8s-at-home/tdarr
# Reference: https://github.com/k8s-at-home/charts/tree/master/charts/stable/tdarr

# Add Function
lastreleaseversion() { git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' "$1" | cut -d/ -f3- | tail -n1 | cut -d '^' -f 1 | cut -d 'v' -f 2; }

# Versions
#Internal Domain name
DOMAIN_NAME=$(hostname -d)
#Internal DNS Entry to that resolves to the Tdarr fqdn - you must make this DNS Entry
TDARR_SQDN="tdarr"
TDARR_FQDN="${TDARR_SQDN}.${DOMAIN_NAME}"
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

# Create Unmanaged Cluster
echo '   Creating Unmanaged Cluster ...'
tanzu um create ${CLUSTER_NAME} -c calico -p 80:80 -p 443:443 

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

## Install Tdarr
echo "   Adding helm repo K8s for tdarr deployment ..."
helm repo add k8s-at-home https://k8s-at-home.com/charts/
helm repo update

# Create Namespace tdarr
echo "   Creating Namespace tdarr ..."
kubectl create namespace tdarr

# Get Timezone from OVA
TZ=$(timedatectl status | grep "Time zone" | cut -d ":" -f 2 | cut -d " " -f 2)
echo "   Applying system timezone $TZ for tdarr ..."

# Install Tdarr
echo "   Using helm to install tdarr ..."
helm install tdarr k8s-at-home/tdarr \
  --namespace tdarr \
  --replace \
  --set hostNetwork="true" \
  --set env.TZ="${TZ}" \
  --set ingress.main.enabled="true" \
  --set persistence.config.enabled="true" \
  --set hostname="${TDARR_SQDN}" \
  --set subdomain="$(hostname -d)" \
  --set service.main.ports.http.port="80" \
  --set node.enabled="true"

# Validate that tdarr pod is ready
echo "   Validate that tdarr pod is ready ..."
TDARRPOD=$(kubectl get po -n tdarr | grep tdarr | cut -d " " -f 1)
while [[ $(kubectl get po -n tdarr $TDARRPOD -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for pod $TDARRPOD to be ready" && sleep 10s; done
echo "   Pod $TDARRPOD is now ready ..."

# Show tdarr  pod info
echo "   tdarr pod info: ..."
kubectl get pods -n tdarr -o wide
kubectl get services -n tdarr -o wide
kubectl describe services -n tdarr
kubectl get ingress -n tdarr -A
#kubectl logs ${TDARRPOD} -n tdarr --all-containers

# Echo Completion
sleep 10s
IP_ADDRESS=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
clear
echo "   Tdarr pod deployed ..."
echo "   You can access tdarr by going to:"
echo "                                      http://$TDARR_FQDN"
echo "                                      or"
echo "                                      http://$IP_ADDRESS"
echo " "
echo "   Note: You must make a DNS or HOST File entry for $TDARR_FQDN to be able to be accessed"
sleep 60s
