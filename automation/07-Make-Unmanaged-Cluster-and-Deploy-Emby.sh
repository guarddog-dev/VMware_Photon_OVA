#!/bin/bash
# Setup EMBY Using Contour
echo '  Preparing for Emby ...'
# Reference https://artifacthub.io/packages/helm/k8s-at-home/emby

# Versions
#Version of Cert Manager to install
CERT_MANAGER_PACKAGE_VERSION=1.8.0
#Version of Contour/Envoy to install
CONTOUR_PACKAGE_VERSION=1.20.1
#Internal Domain name
DOMAIN_NAME=$(hostname -d)
#Internal DNS Entry to that resolves to the EMBY fqdn - you must make this DNS Entry
EMBY_FQDN="emby.${DOMAIN_NAME}"
#EMBY Admin Password
EMBY_ADMIN_PASSWORD='VMware12345!'
#Tanzu/Kubernetes cluster name
CLUSTER_NAME='local-cluster'
#Control Plane Name
CONTROL_PLANE="$CLUSTER_NAME"-control-plane
#Location Name
USERD=root
# Github Variables for YAML files
REPO="https://github.com/guarddog-dev"
REPONAME="VMware_Photon_OVA"
REPOFOLDER="yaml"

# Create Unmanaged Cluster
echo '   Creating Unmanaged Cluster ...'
tanzu um create $CLUSTER_NAME -p 80:80 -p 443:443 -p 8096:8096 -c calico

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

# Install Cert Manager
echo "   Installing Cert Manager version ${CERT_MANAGER_PACKAGE_VERSION}..."
# https://tanzucommunityedition.io/docs/v0.12/package-readme-cert-manager-1.8.0/
tanzu package available list cert-manager.community.tanzu.vmware.com
tanzu package install cert-manager --package-name cert-manager.community.tanzu.vmware.com --version ${CERT_MANAGER_PACKAGE_VERSION}
tanzu package installed list -n default

#Validate Package is Running
PNAME="Cert Manager"
PACKAGE="cert-manager"
CSTATUS='NotRunning'
echo "   Validating $PNAME is ready ..."
while [[ $CSTATUS != "Running" ]]
do
echo "    $PNAME - NotRunning"
APPNAME=$(kubectl -n $PACKAGE get po -l app=$PACKAGE -o name | cut -d '/' -f 2)
CSTATUS=$(kubectl get po -n $PACKAGE | grep $APPNAME | awk '{print $3}')
done
echo "$PNAME - $CSTATUS"
kubectl get po -n $PACKAGE | grep $APPNAME

#Validate Tanzu Package is reconciled
PNAME="Cert Manager"
PACKAGE="cert-manager"
CSTATUS='NotReconziled'
echo "> Validating $PNAME is reconciled..."
while [[ $CSTATUS != "Reconcile succeeded" ]]
do
echo "    $PNAME not reconciled"
CSTATUS=$(tanzu package installed get $PACKAGE | grep STATUS | awk '{print $2" "$3}')
done
echo "$PNAME $CSTATUS"
tanzu package installed get $PACKAGE | grep STATUS
sleep 20s

# Install Contour
echo "   Installing Contour version ${CONTOUR_PACKAGE_VERSION} ..."
# https://tanzucommunityedition.io/docs/v0.12/package-readme-contour-1.20.1/
tanzu package available list contour.community.tanzu.vmware.com
cat <<EOF >contour-values.yaml
envoy:
  service:
    type: ClusterIP
  hostPorts:
    enable: true
EOF
tanzu package install contour \
  --package-name contour.community.tanzu.vmware.com \
  --version ${CONTOUR_PACKAGE_VERSION} \
  --values-file contour-values.yaml

<<com
#Validate Package is Running
PNAME="projectcontour"
PACKAGE="contour"
APPNAME=$(kubectl -n $PNAME get po -l app=$PACKAGE -o name | cut -d '/' -f 2)
echo "> Validating $PNAME is ready..."
for index in "${APPNAME[@]}"
do
        CSTATUS='NotRunning'
        while [[ $CSTATUS != "Running" ]]
        do
                echo "${APPNAME[index]} - NotRunning"
                CSTATUS=$(kubectl get po -n $PNAME | grep ${APPNAME[index]} | awk '{print $3}')
        done
echo "   ${APPNAME[index]} - $CSTATUS"
done
com

#Validate Tanzu Package is reconciled
PNAME="projectcontour"
PACKAGE="contour"
CSTATUS='NotReconziled'
echo "   Validating $PNAME is reconciled ..."
while [[ $CSTATUS != "Reconcile succeeded" ]]
do
echo "$PNAME not reconciled"
CSTATUS=$(tanzu package installed get $PACKAGE | grep STATUS | awk '{print $2" "$3}')
sleep 5s
done
echo "$PNAME $CSTATUS"
sleep 20s

## Install EMBY
echo "   Adding helm repo k8s-at-home for Emby deployment ..."
helm repo add k8s-at-home https://k8s-at-home.com/charts/
helm repo update

# Create Namespace EMBY
echo "   Creating Namespace emby ..."
kubectl create namespace emby

# Get Timezone from OVA
TZ=$(timedatectl status | grep "Time zone" | cut -d ":" -f 2 | cut -d " " -f 2)
echo "   System Timezone is $TZ ..."

# Install EMBY
echo "   Using helm to install Emby ..."
helm install emby k8s-at-home/emby \
  --namespace emby \
  --replace \
  --set env.TZ="${TZ}" \
  --set persistence.config.enabled="true" \
  --set persistence.config.size="20Gi" \
  --set persistence.config.retain="true" \
  --set image.tag="latest"

# Validate that EMBY pod is ready
echo "   Validate that emby pod in namespace emby is ready ..."
EMBYPOD=$(kubectl get po -n emby | grep emby | cut -d " " -f 1)
while [[ $(kubectl get po -n emby $EMBYPOD -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "   Waiting for pod $EMBYPOD to be ready ..." && sleep 10s; done
echo "   Pod $EMBYPOD is now ready ..."

# Echo pod info
echo "   Info on new pod includes:"
kubectl get pods -n emby -o wide
kubectl get pvc -n emby
kubectl get services -n emby -o wide
#kubectl logs $(EMBYPOD) -n emby --all-containers
echo " "

# Create EMBY ingress rules
echo "   Creating Emby ingress rules ..."
cat <<EOF > emby-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: emby-web
  namespace: emby
spec:
  rules:
  - host: $EMBY_FQDN
    http:
      paths:
      - pathType: Prefix
        path: /
        backend:
          service:
            name: emby
            port:
              number: 8096
EOF

# Apply EMBY ingress rules
echo "   Applying EMBY ingress rules ..."
kubectl apply -f emby-ingress.yaml

kubectl get all,ingress -n emby

# Open Emby External port
echo "   Applying iptables ingress port ..."
sudo iptables -I INPUT -p tcp -m tcp --dport 8096 -j ACCEPT
sudo iptables-save > /etc/systemd/scripts/ip4save

# Echo Completion
sleep 10s
clear
echo "   EMBY pod deployed ..."
echo "   You can access EMBY by going to:"
echo "                                      http://$EMBY_FQDN/8096"
echo " "
echo "   Note: You must make a DNS or HOST File entry for $EMBY_FQDN to be able to be accessed."
echo "   Note: You will need to have 20Gi of space on your kubernetes appliance for emby db/logs."
sleep 60s
