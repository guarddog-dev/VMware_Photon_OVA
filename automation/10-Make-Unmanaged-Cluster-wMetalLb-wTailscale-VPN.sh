#!/bin/bash
# Setup Tailscale VPN
echo '   Creating Unmanaged Cluster with Tailscale VPN ...'
# Reference: https://tailscale.com/kb/1185/kubernetes/

#Request Tailscale Auth Key
echo " "
echo "   Please provide the Tailscale Auth Key ..."
echo "   Example: tskey-123456789ABCDEF"
read AUTH_KEY
echo "   Will use AUTH Key $AUTH_KEY ..."
echo " "

# Versions
# MetalLb Load Balancer Version
METALLBVERSION="0.12.1"
#Version of Local Path Storage to install
LOCAL_PATH_STORAGE_PACKAGE_VERSION="0.0.20"
#Tanzu/Kubernetes cluster name
CLUSTER_NAME='local-cluster'
#Control Plane Name
CONTROL_PLANE="$CLUSTER_NAME"-control-plane

# Create Unmanaged Cluster
echo '   Creating Unmanaged Cluster ...'
tanzu um create $CLUSTER_NAME -c calico -p 80:80 -p 443:443 -p 1194:1194 -p 9443:9443

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

# Clone Repo
echo "   Cloning Tailscale Repo ..."
git clone https://github.com/tailscale/tailscale.git
cd tailscale/docs/k8s

# Create secret with tailscale AUTH Key
echo "   Creating Auth key secret for tailscale ..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tailscale-auth
stringData:
  AUTH_KEY: $AUTH_KEY
EOF

# Configure RBAC
echo "   Configuring RBAC for tailscale ..."
export SA_NAME=tailscale
export TS_KUBE_SECRET=tailscale-auth
make rbac

<<com
# Create Namespace
echo "   Creating Namespace tailscale ..."
kubectl create namespace tailscale

# Create Tailscale Nginx Proxy
echo "   Creating Tailscale Nginx Proxy ..."
kubectl create deployment nginx --image nginx --namespace tailscale
kubectl expose deployment nginx --port 80 --namespace tailscale
export TS_DEST_IP="$(kubectl get svc nginx --namespace tailscale -o=jsonpath='{.spec.clusterIP}')"
make proxy
com

# Create Namespace
echo "   Creating Namespace metallb-system ..."
kubectl create namespace metallb-system

# Install MetalLb
echo "   Installing MetalLb Loadbalancer ..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLBVERSION}/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v${METALLBVERSION}/manifests/metallb.yaml
kubectl -n metallb-system get all

## Set Cluster IPs
echo "   Creating MetalLb IP Pool ..."
CLUSTERIP=$(kubectl get nodes -n ${CONTROL_PLANE} -o yaml | grep "address: 1" | cut -d ":" -f 2 | cut -d " " -f 2)
#BASEIP=$(echo $ETH_IP | cut -d "." -f1-3)
BASEIP=$(echo $CLUSTERIP | cut -d "." -f1-3)
BEGINIP=${BASEIP}.100
ENDIP=${BASEIP}.200
kubectl apply -f - <<EOF
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
kubectl get configmap -n metallb-system config -o yaml

# Setup Tailscale Subnet Router
echo "   Setting up Tailscale Subnet Router ..."
# Reference https://tailscale.com/kb/1019/subnets/
CLUSTER_CIDR=$(echo '{"apiVersion":"v1","kind":"Service","metadata":{"name":"tst"},"spec":{"clusterIP":"1.1.1.1","ports":[{"port":443}]}}' | kubectl apply -f - 2>&1 | sed 's/.*valid IPs is //')
SERVICE_CIDR="${BASEIP}.0/24"
POD_CIDR=$(kubectl get nodes -n ${CONTROL_PLANE}  -o jsonpath='{.items[*].spec.podCIDR}')
export TS_ROUTES=$CLUSTER_CIDR,$SERVICE_CIDR,$POD_CIDR
make subnet-router
ROUTERPOD=$(kubectl get po -n default | grep subnet-router | cut -d " " -f 1)
while [[ $(kubectl get po $ROUTERPOD -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for pod $ROUTERPOD to be ready" && sleep 1; done
sleep 10s
kubectl logs subnet-router
