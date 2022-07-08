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

# Create Unmanaged Cluster
echo '   Creating Unmanaged Cluster ...'
tanzu um create $CLUSTER_NAME -p 80:80 -p 443:443 -c calico

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

## Setup Metallb Loadbalancer
echo "   Setting up Metallb Loadbalancer ..."
## Install MetalLB (load-balancer)
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLBVERSION}/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLBVERSION}/manifests/metallb.yaml
kubectl -n metallb-system get all

## Set Metallb IPs
echo "   Setting Metallb loadbalancer IPs ..."
CLUSTERIP=$(kubectl get nodes -n local-cluster-control-plane -o yaml | grep "address: 1" | cut -d ":" -f 2 | cut -d " " -f 2)
BASEIP=$(echo $CLUSTERIP | cut -d "." -f1-3)
BEGINIP=${BASEIP}.100
ENDIP=${BASEIP}.110
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
  --set extraEnvVars.TZ="${TZ}" \
  --set serviceDns.type="LoadBalancer" \
  --set serviceDhcp.type="LoadBalancer" \
  --set serviceWeb.type="LoadBalancer" \
  --set virtualHost="pi.hole" \
  --set ingress.enabled="true" \
  --set ingress.hosts[0]="$(hostname -d)" \
  --set persistentVolumeClaim.enabled="true" \
  --set admin.existingSecret="pihole-secret" \
  --set doh.enabled="true" \
  --set hostname="pihole" \
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
kubectl describe services -n pihole pihole-web
kubectl logs ${PIHOLEPOD} -n pihole --all-containers
kubectl get ingress -n pihole -A

<<com
# Create Pihole ingress rules
echo "   Creating pihole ingress rules ..."
cat <<EOF > ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pihole-web
  namespace: pihole
spec:
  rules:
  - host: $PIHOLE_FQDN
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: pihole-web
            port:
              number: 80
EOF

# Apply Pihole ingress rules
echo "   Applying pihole ingress rules ..."
kubectl apply -f ingress.yaml
com

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
