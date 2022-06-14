#!/bin/bash
# Setup Prometheus and Grafana
# https://tanzucommunityedition.io/docs/v0.12/docker-monitoring-stack/
echo '> Preparing for Prometheus and Grafana...'

# Versions
#Version of Cert Manager to install
CERT_MANAGER_PACKAGE_VERSION="1.8.0"
#Version of Contour/Envoy to install
CONTOUR_PACKAGE_VERSION="1.20.1"
#Version of Local Path Storage to install
LOCAL_PATH_STORAGE_PACKAGE_VERSION="0.0.20"
#Version of Prometheus to install
PROMETHEUS_PACKAGE_VERSION="2.27.0-1"
#Version of Grafana to install
GRAFANA_PACKAGE_VERSION="7.5.11"
#Internal Domain name
DOMAIN_NAME=$(echo $HOSTNAME | cut -d '.' -f 2-3)
#Internal DNS Entry to that resolves to the prometheus fqdn - you must make this DNS Entry
PROMETHEUS_FQDN="prometheus.${DOMAIN_NAME}"
#Internal DNS Entry to that resolves to the grafana fqdn - you must make this DNS Entry
GRAFANA_FQDN="grafana.${DOMAIN_NAME}"
#Grafana default admin password
GRAFANA_ADMIN_PASSWORD="VMware12345!"
#Tanzu/Kubernetes cluster name
CLUSTER_NAME='local-cluster'
#Control Plane Name
CONTROL_PLANE="$CLUSTER_NAME"-control-plane		

# Create Unmanaged Cluster
echo "> Creating Unmanaged Cluster $CLUSTER_NAME..."
tanzu um create $CLUSTER_NAME -p 80:80 -p 443:443 -c calico

# Valideate Cluster is ready
echo "> Validating Unmanaged Cluster $CLUSTER_NAME is Ready..."
STATUS=NotReady
while [[ $STATUS != "Ready" ]]
do
echo "Tanzu Cluster $CLUSTER_NAME Status - NotReady"
sleep 10s
STATUS=$(kubectl get nodes -n $CONTROL_PLANE | tail -n +2 | awk '{print $2}')
done
echo "Tanzu Kubernetes Cluster $CLUSTER_NAME Status - Ready"
kubectl get nodes,po -A
sleep 20s

# Install Cert Manager
echo "> Installing Cert Manager version ${CERT_MANAGER_PACKAGE_VERSION}..."
# https://tanzucommunityedition.io/docs/v0.12/package-readme-cert-manager-1.8.0/
tanzu package available list cert-manager.community.tanzu.vmware.com
tanzu package install cert-manager --package-name cert-manager.community.tanzu.vmware.com --version ${CERT_MANAGER_PACKAGE_VERSION}
tanzu package installed list -n default

#Validate Package is Running
PNAME="Cert Manager"
PACKAGE="cert-manager"
CSTATUS='NotRunning'
echo "> Validating $PNAME is ready..."
while [[ $CSTATUS != "Running" ]]
do
echo "$PNAME - NotRunning"
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
echo "$PNAME not reconciled"
CSTATUS=$(tanzu package installed get $PACKAGE | grep STATUS | awk '{print $2" "$3}')
done
echo "$PNAME $CSTATUS"
tanzu package installed get $PACKAGE
sleep 20s

# Install Contour
echo "> Installing Contour version ${CONTOUR_PACKAGE_VERSION}..."
# https://tanzucommunityedition.io/docs/v0.12/package-readme-contour-1.20.1/
tanzu package available list contour.community.tanzu.vmware.com
cat <<EOF >contour-values.yaml
envoy:
  service:
    type: ClusterIP
  hostPorts:
    enable: true
  certificates:
    useCertManager: true
EOF
tanzu package install contour \
  --package-name contour.community.tanzu.vmware.com \
  --version ${CONTOUR_PACKAGE_VERSION} \
  --values-file contour-values.yaml

#Validate Tanzu Package is reconciled
PNAME="projectcontour"
PACKAGE="contour"
CSTATUS='NotReconziled'
echo "> Validating $PNAME is reconciled..."
while [[ $CSTATUS != "Reconcile succeeded" ]]
do
echo "$PNAME not reconciled"
CSTATUS=$(tanzu package installed get $PACKAGE | grep STATUS | awk '{print $2" "$3}')
sleep 5s
done
echo "$PNAME $CSTATUS"
tanzu package installed get $PACKAGE
sleep 20s

# Install Local Path Storage
echo "> Installing Local Path Storage version ${LOCAL_PATH_STORAGE_PACKAGE_VERSION}..."
tanzu package available list local-path-storage.community.tanzu.vmware.com
tanzu package install local-path-storage --package-name local-path-storage.community.tanzu.vmware.com --version ${LOCAL_PATH_STORAGE_PACKAGE_VERSION}
tanzu package installed list -n default

#Validate Package is Running
PNAME="local-path-storage"
PACKAGE="local-path-storage"
CSTATUS='NotRunning'
echo "> Validating $PNAME is ready..."
while [[ $CSTATUS != "Running" ]]
do
echo "$PNAME - NotRunning"
APPNAME=$(kubectl -n $PACKAGE get po -o name | cut -d '/' -f 2)
CSTATUS=$(kubectl get po -n $PACKAGE | grep $APPNAME | awk '{print $3}')
done
echo "$PNAME - $CSTATUS"
kubectl get po -n $PACKAGE | grep $APPNAME

#Validate Tanzu Package is reconciled
PNAME="local-path-storage"
PACKAGE="local-path-storage"
CSTATUS='NotReconziled'
echo "> Validating $PNAME is reconciled..."
while [[ $CSTATUS != "Reconcile succeeded" ]]
do
echo "$PNAME not reconciled"
CSTATUS=$(tanzu package installed get $PACKAGE | grep STATUS | awk '{print $2" "$3}')
sleep 5s
done
echo "$PNAME $CSTATUS"
tanzu package installed get $PACKAGE
sleep 20s

#Set Local-Storage-Path as default
echo "> Setting local-storage-path as the default storageclass..."
kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl get sc

# Prepare Install Prometheus
echo "> Preparing for Prometheus version ${PROMETHEUS_PACKAGE_VERSION}..."
tanzu package available list prometheus.community.tanzu.vmware.com
echo '> Downloading Prometheus files...'
image_url=$(kubectl get packages prometheus.community.tanzu.vmware.com.${PROMETHEUS_PACKAGE_VERSION} -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
imgpkg pull -b $image_url -o /tmp/prometheus-package
cp /tmp/prometheus-package/config/values.yaml prometheus-data-values.yaml
SEDINPUT='s/virtual_host_fqdn: "prometheus.system.tanzu"/virtual_host_fqdn: "'$PROMETHEUS_FQDN'"/g'
sed -i "$SEDINPUT" prometheus-data-values.yaml
sed -i "s/ enabled: false/ enabled: true/g" prometheus-data-values.yaml
echo '> Removing comments in prometheus-data-values.yaml file...'
yq -i eval '... comments=""' prometheus-data-values.yaml
# Install Prometheus
echo "> Installing Prometheus version ${PROMETHEUS_PACKAGE_VERSION}..."
tanzu package install prometheus -p prometheus.community.tanzu.vmware.com -v ${PROMETHEUS_PACKAGE_VERSION} --values-file prometheus-data-values.yaml

#Validate Tanzu Package is reconciled
PNAME="prometheus"
PACKAGE="prometheus"
CSTATUS='NotReconziled'
echo "> Validating $PNAME is reconciled..."
while [[ $CSTATUS != "Reconcile succeeded" ]]
do
echo "$PNAME not reconciled"
CSTATUS=$(tanzu package installed get $PACKAGE | grep STATUS | awk '{print $2" "$3}')
sleep 5s
done
echo "$PNAME $CSTATUS"

#Validate Package is Running
PNAME="prometheus"
PACKAGE="prometheus"
CSTATUS='NotRunning'
echo "> Validating $PNAME is ready..."
while [[ $CSTATUS != "Running" ]]
do
echo "$PNAME - NotRunning"
APPNAME=$(kubectl -n $PACKAGE get po -l app=$PACKAGE -o name | grep prometheus-server | cut -d '/' -f 2)
CSTATUS=$(kubectl get po -n $PACKAGE | grep $APPNAME | awk '{print $3}')
done
echo "$PNAME - $CSTATUS"
kubectl get po -n $PACKAGE | grep $APPNAME

#List storage of Prometheus
kubectl get pvc -A

#List Promethus Pods and services
kubectl get pods,svc -n prometheus

#Validate HTTPProxy for Prometheus
kubectl get HTTPProxy -n prometheus

#Get HTTPProxy Port for Prometheus
PACKAGE="prometheus"
APPNAME=$(kubectl -n $PACKAGE get po -l app=$PACKAGE -o name | grep prometheus-server | cut -d '/' -f 2)
kubectl get pods $APPNAME -n prometheus -o jsonpath='{.spec.containers[*].name}{.spec.containers[*].ports}'

#validate prometheus is accessible
curl -Lk https://$HOSTNAME

# Prepare for Grafana
echo "> Preparing for Grafana version ${GRAFANA_PACKAGE_VERSION}..."
tanzu package available list grafana.community.tanzu.vmware.com
echo '> Downloading Grafana files...'
image_url=$(kubectl get packages grafana.community.tanzu.vmware.com.${GRAFANA_PACKAGE_VERSION} -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
imgpkg pull -b $image_url -o /tmp/grafana-package
cp /tmp/grafana-package/config/values.yaml grafana-data-values.yaml
#modify grafana yaml
echo "> Modifying Grafana yaml file..."
SEDINPUT='s/virtual_host_fqdn: "grafana.system.tanzu"/virtual_host_fqdn: "'$GRAFANA_FQDN'"/g'
sed -i "$SEDINPUT" grafana-data-values.yaml
sed -i "s/ enabled: false/ enabled: true/g" grafana-data-values.yaml
GRAFANA_BASE64_ADMIN_PASSWORD=$( echo -n "$GRAFANA_ADMIN_PASSWORD" | base64 )
SEDINPUT='s/admin_password: ""/admin_password: "'$GRAFANA_BASE64_ADMIN_PASSWORD'"/g' 
sed -i "$SEDINPUT" grafana-data-values.yaml
echo '> Removing comments in grafana-data-values.yaml file...'
yq -i eval '... comments=""' grafana-data-values.yaml
sed -i "s/type: LoadBalancer/type: ClusterIP/g" grafana-data-values.yaml
# Install Grafana
echo "> Installing Grafana version ${GRAFANA_PACKAGE_VERSION}..."
tanzu package install grafana \
   --package-name grafana.community.tanzu.vmware.com \
   --version ${GRAFANA_PACKAGE_VERSION} \
   --values-file grafana-data-values.yaml
   
#Get HTTPProxy Port for grafana
PACKAGE="grafana"
APPNAME=$(kubectl -n $PACKAGE get po -L app=$PACKAGE | grep grafana | cut -d ' ' -f 1)
kubectl get pods $APPNAME -n $PACKAGE -o jsonpath='{.spec.containers[*].name}{.spec.containers[*].ports}'

#Validate Tanzu Package is reconciled
PNAME="grafana"
PACKAGE="grafana"
CSTATUS='NotReconziled'
echo "> Validating $PNAME is reconciled..."
while [[ $CSTATUS != "Reconcile succeeded" ]]
do
echo "$PNAME not reconciled"
CSTATUS=$(tanzu package installed get $PACKAGE | grep STATUS | awk '{print $2" "$3}')
sleep 5s
done
echo "$PNAME $CSTATUS"

#Validate Package is Running
PNAME="grafana"
PACKAGE="grafana"
CSTATUS='NotRunning'
echo "> Validating $PNAME is ready..."
while [[ $CSTATUS != "Running" ]]
do
echo "$PNAME - NotRunning"
APPNAME=$(kubectl -n $PACKAGE get po -L app=$PACKAGE | grep grafana | cut -d ' ' -f 9)
CSTATUS=$(kubectl get po -n $PACKAGE | grep $APPNAME | awk '{print $3}')
done
echo "$PNAME - $CSTATUS"
kubectl get po -n $PACKAGE | grep $APPNAME

#Echo Info to end user
clear
echo "You can now access the Prometheus at:"
echo "					     https://$PROMETHEUS_FQDN"
echo "You can now access the Grafana at:"
echo "					  https://$GRAFANA_FQDN"
echo "Grafana Username: admin"
echo "Grafana Password: $GRAFANA_ADMIN_PASSWORD"
echo "Note you must either have a DNS A record in your DNS or a /etc/host entry added for the hostname $PROMETHEUS_FQDN and $GRAFANA_FQDN pointing to the external IP of your Tanzu Kubernetes Cluster"
echo "Prometheus website & documentation can be found here: https://prometheus.io"
echo "Grafana website & documentation can be found here: https://grafana.com"
sleep 60s
