#!/bin/bash
# Setup Pi-Hole Using Contour
echo '  Preparing for Pi-Hole ...'

# Versions
#Version of Cert Manager to install
CERT_MANAGER_PACKAGE_VERSION=1.8.0
#Version of Contour/Envoy to install
CONTOUR_PACKAGE_VERSION=1.20.1
#Internal Domain name
DOMAIN_NAME=$(echo $HOSTNAME | cut -d '.' -f 2-3)
#Internal DNS Entry to that resolves to the Pi-hole fqdn - you must make this DNS Entry
PIHOLE_FQDN="pihole.${DOMAIN_NAME}"
#Pihole Admin Password
PIHOLE_ADMIN_PASSWORD="VMware12345!"
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

## Install Pi-Hole
echo "   Adding helm repo mojo2600 for pihole deployment ..."
#Reference https://greg.jeanmart.me/2020/04/13/self-host-pi-hole-on-kubernetes-and-block-ad/
helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/
helm repo update

## Download pihole yaml file from registry
# Download Repo Folder
echo -e "\e[92m  Downloading YAML Repo Folder ..." > /dev/console
git clone --filter=blob:none --sparse ${REPO}/${REPONAME}
cd ${REPONAME}
git sparse-checkout init --cone
git sparse-checkout add ${REPOFOLDER}
cd ${REPOFOLDER}
mv pihole.values.yaml /${USERD}/automation/.
echo -e "\e[92m  Cleaning up YAML Repo Folder ..." > /dev/console
rm -rf *
rm -rf .*
cd ..
rmdir ${REPOFOLDER}
# clean up Repo Folder
rm -rf *
rm -rf .*
cd ..
rmdir ${REPONAME}

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
echo "   System Timezone is $TZ ..."
echo "   Updating yaml with System Timezone ..."
sudo sed -i "s#UTC#$TZ#g" /${USERD}/automation/pihole.values.yaml

# Install Pihole
echo "   Using helm to install pihole ..."
helm install pihole mojo2600/pihole \
  --namespace pihole \
  --values pihole.values.yaml \
  --replace 

# Validate that pihole pod is ready
echo "   Validate that pihole pod is ready ..."
PIHOLEPOD=$(kubectl get po -n pihole | grep pihole | cut -d " " -f 1)
while [[ $(kubectl get po -n pihole $PIHOLEPOD -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "   Waiting for pod $PIHOLEPOD to be ready ..." && sleep 10s; done
echo "   Pod $PIHOLEPOD is now ready ..."

# Echo pod info
echo "   Info on new pod includes:"
kubectl get pods -n pihole -o wide
kubectl get pvc -n pihole
kubectl get services -n pihole -o wide

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