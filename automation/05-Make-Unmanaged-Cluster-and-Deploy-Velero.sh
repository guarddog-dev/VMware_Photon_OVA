#!/bin/bash
# Setup Velero
echo '   Creating Unmanaged Cluster with Velero package ...'

# Versions
VELERO_PACKAGE_VERSION=1.8.0
#Tanzu/Kubernetes cluster name
CLUSTER_NAME='local-cluster'
#Control Plane Name
CONTROL_PLANE="$CLUSTER_NAME"-control-plane

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

# Install Velero
echo '    Installing Velero ...'
# https://tanzucommunityedition.io/docs/v0.12/package-readme-cert-manager-1.8.0/
tanzu package available list velero.community.tanzu.vmware.com
tanzu package install velero --package-name velero.community.tanzu.vmware.com --version ${VELERO_PACKAGE_VERSION}

