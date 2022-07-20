#!/bin/bash
# Setup Pi-Hole
echo '  Preparing for Pi-Hole ...'
# Reference: https://artifacthub.io/packages/helm/mojo2600/pihole
# Reference: https://greg.jeanmart.me/2020/04/13/self-host-pi-hole-on-kubernetes-and-block-ad/

# Add Function
lastreleaseversion() { git -c 'versionsort.suffix=-' ls-remote --tags --sort='v:refname' "$1" | cut -d/ -f3- | tail -n1 | cut -d '^' -f 1 | cut -d 'v' -f 2; }

# Versions
#Version of MetalLB to install
#RELEASEURL="https://github.com/metallb/metallb"
#VERSION=$(lastreleaseversion ${RELEASEURL})
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

## Install MetalLB (load-balancer)
echo "   Setting up MetalLb Load-balancer ..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLBVERSION}/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLBVERSION}/manifests/metallb.yaml
kubectl -n metallb-system get all

## Create MetalLB IP Pool
echo "   Creating MetalLb Load-balancer IP Pool..."
ETHIP=$(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
CLUSTERIP=$(kubectl get nodes -n local-cluster-control-plane -o yaml | grep "address: 1" | cut -d ":" -f 2 | cut -d " " -f 2)
#docker ps -q | xargs -n 1 docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Name }}' | sed 's/ \// /'
BASEIP=$(echo $CLUSTERIP | cut -d "." -f1-2)
BRIDGEGATEWAY=$(docker network inspect bridge --format "{{(index .IPAM.Config 0).Gateway}}")
#BASEIP=$(echo $BRIDGEGATEWAY | cut -d "." -f1-2)
BEGINIP=${BASEIP}.255.1
ENDIP=${BASEIP}.255.250
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

## Install Pi-Hole
echo "   Adding helm repo mojo2600 for pihole deployment ..."
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
  --set serviceDns.type="LoadBalancer" \
  --set serviceDhcp.type="LoadBalancer" \
  --set serviceWeb.type="ClusterIP" \
  --set virtualHost="pihole" \
  --set ingress.enabled="true" \
  --set ingress.hosts[0]="$(hostname -d)" \
  --set persistentVolumeClaim.enabled="true" \
  --set admin.existingSecret="pihole-secret" \
  --set doh.enabled="true" \
  --set hostname="pihole" \
  --set dnsHostPort.enabled="true" \
  --set serviceDns.mixedService="false" \
  --set subdomain="$(hostname -d)"

# Validate that pihole pod is ready
echo "   Validate that pihole pod is ready ..."
PIHOLEPOD=$(kubectl get po -n pihole | grep pihole | cut -d " " -f 1)
while [[ $(kubectl get po -n pihole $PIHOLEPOD -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for pod $PIHOLEPOD to be ready" && sleep 10s; done
echo "   Pod $PIHOLEPOD is now ready ..."

# Show pihole pod info
echo "   Pihole pod info: ..."
kubectl get pods -n pihole -o wide
kubectl get services -n pihole -o wide
kubectl describe services -n pihole
kubectl get ingress -n pihole -A
#kubectl logs ${PIHOLEPOD} -n pihole --all-containers

# Test NSLOOKUP against Pihole
echo "   Testing Piholes DNS ..."
NODE_IP=$(kubectl get node ${CONTROL_PLANE} -o yaml | grep 'projectcalico.org/IPv4Address:' | cut -d " " -f 6 | cut -d "/" -f 1)
nslookup vmware.com ${NODE_IP}

# Create Ingress Rule
echo "   Creating Ingress Rules ..."
sudo iptables -A FORWARD -i eth0 -j ACCEPT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -t nat -I POSTROUTING -s 127.0.0.1 -d ${NODE_IP} -j MASQUERADE
#echo "   Creating Ingress Rules for HTTP port 80 ..."
METALLBWEBTCPIP=$(kubectl get svc -n pihole pihole-web --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
#sudo iptables -t nat -I PREROUTING -i lo -d 127.0.0.1 -p tcp --dport 80 -j DNAT --to-destination ${METALLBWEBTCPIP}:80
#sudo iptables -t nat -I PREROUTING -i eth0 -p tcp --dport 80 -j DNAT --to-destination ${METALLBWEBTCPIP}:80
#sudo iptables -t nat -I OUTPUT -o lo -p tcp --dport 80 -j DNAT --to-destination ${METALLBWEBTCPIP}:80
echo "   Creating Ingress Rules for DNS port 53 ..."
METALLBDNSTCPIP=$(kubectl get svc -n pihole pihole-dns-tcp --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
METALLBDNSUDPIP=$(kubectl get svc -n pihole pihole-dns-udp --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
sudo iptables -t nat -I PREROUTING -i lo -d 127.0.0.1 -p tcp --dport 53 -j DNAT --to-destination ${METALLBDNSTCPIP}:53
sudo iptables -t nat -I PREROUTING -i lo -d 127.0.0.1 -p udp --dport 53 -j DNAT --to-destination ${METALLBDNSUDPIP}:53
sudo iptables -t nat -I PREROUTING -i eth0 -p tcp --dport 53 -j DNAT --to-destination ${METALLBDNSTCPIP}:53
sudo iptables -t nat -I PREROUTING -i eth0 -p udp --dport 53 -j DNAT --to-destination ${METALLBDNSUDPIP}:53
sudo iptables -t nat -I OUTPUT -o lo -p tcp --dport 53 -j DNAT --to-destination ${METALLBDNSTCPIP}:53
sudo iptables -t nat -I OUTPUT -o lo -p udp --dport 53 -j DNAT --to-destination ${METALLBDNSUDPIP}:53
echo "   Creating Ingress Rules for DHCP port 67 ..."
METALLBDHCPUDPIP=$(kubectl get svc -n pihole pihole-dhcp --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
sudo iptables -t nat -I PREROUTING -i lo -d 127.0.0.1 -p udp --dport 67 -j DNAT --to-destination ${METALLBDHCPUDPIP}:67
sudo iptables -t nat -I PREROUTING -i eth0 -p udp --dport 67 -j DNAT --to-destination ${METALLBDHCPUDPIP}:67
sudo iptables -t nat -I OUTPUT -o lo -p udp --dport 67 -j DNAT --to-destination ${METALLBDHCPUDPIP}:67
echo "   Saving IP Tables Config ..."
sudo iptables-save > /etc/systemd/scripts/ip4save

# Setup Pihole for local DNS resolution
#echo "   Setting Pihole DNS resolution for local PhotonOS ..."
#sudo unlink /etc/resolv.conf
#NODE_IP=$(kubectl get node ${CONTROL_PLANE} -o yaml | grep 'projectcalico.org/IPv4Address:' | cut -d " " -f 6 | cut -d "/" -f 1)
#sudo echo "nameserver ${NODE_IP}" | sudo tee /etc/resolv.conf
#sudo systemctl enable systemd-resolved
#sudo systemctl start systemd-resolved

# Echo Completion
sleep 10s
IP_ADDRESS=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
clear
echo "   Pihole pod deployed ..."
echo "   You can access Pihole by going to:"
echo "                                      http://$PIHOLE_FQDN/admin"
echo "                                      or"
echo "                                      http://$IP_ADDRESS/admin"
echo " "
echo "   Management Password: $PIHOLE_ADMIN_PASSWORD"
echo " "
echo "   Note: You must make a DNS or HOST File entry for $PIHOLE_FQDN to be able to be accessed"
echo " "
echo "   Use the below commands to test the Pihole DNS Server from within the OVA"
echo "   NODE_IP=$(kubectl get node ${CONTROL_PLANE} -o yaml | grep 'projectcalico.org/IPv4Address:' | cut -d " " -f 6 | cut -d "/" -f 1)"
echo '   nslookup vmware.com ${NODE_IP}'
sleep 60s
