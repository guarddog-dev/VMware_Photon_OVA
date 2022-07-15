#!/bin/bash
# Setup Cluster with Contour
echo '  Preparing for Contour ...'

# Versions
#Version of Cert Manager to install
CERT_MANAGER_PACKAGE_VERSION=1.8.0
#Version of Contour/Envoy to install
CONTOUR_PACKAGE_VERSION=1.20.1
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
echo "${APPNAME[index]} - $CSTATUS"
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

# Echo Completion
sleep 10s
#IP_ADDRESS=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
clear
echo "   Contour deployed ..."
sleep 60s
