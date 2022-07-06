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
#Tanzu/Kubernetes cluster name
CLUSTER_NAME='local-cluster'
#Control Plane Name
CONTROL_PLANE="$CLUSTER_NAME"-control-plane
#Location Name
USERD=root

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

# Get Timezone from OVA
TZ=$(timedatectl status | grep "Time zone" | cut -d ":" -f 2 | cut -d " " -f 2)
echo "   Timezone will be $TZ"


<<com
#create directories for pihole
mkdir -p /data/pihole/{etc,dnsmasq.d}
chmod go+r /data/pihole/{etc,dnsmasq.d}

# Create Namespace pihole
echo "   Creating namespace pihole"
kubectl create namespace pihole

cat <<EOF >pihole.yaml
#Reference https://uthark.github.io/post/2021-10-06-running-pihole-kubernetes/
apiVersion: v1
kind: Pod
metadata:
  name: pihole
  namespace: pihole
spec:
  hostNetwork: true
  dnsPolicy: "None"
  dnsConfig:
    nameservers:
      # upstream DNS used by pihole.
      - 1.1.1.1
  containers:
    - name: pihole
      # https://hub.docker.com/r/pihole/pihole/tags
      image: pihole/pihole:2021.10
      imagePullPolicy: IfNotPresent
      env:
        - name: TZ
          value: ${TZ}
        - name: WEBPASSWORD
          value: VMware12345!
      securityContext:
        privileged: true
      ports:
        - containerPort: 53
          protocol: TCP
        - containerPort: 53
          protocol: UDP
        - containerPort: 67
          protocol: UDP
        - containerPort: 80
          protocol: TCP
        - containerPort: 443
          protocol: TCP
      volumeMounts:
        - name: etc
          mountPath: /etc/pihole
        - name: dnsmasq
          mountPath: /etc/dnsmasq.d
      resources:
        requests:
          memory: 128Mi
          cpu: 100m
        limits:
          memory: 2Gi
          cpu: 1
  volumes:
    - name: etc
      hostPath:
        path: /data/pihole/etc
        type: Directory
    - name: dnsmasq
      hostPath:
        path: /data/pihole/dnsmasq.d
        type: Directory
EOF
kubectl apply -f pihole.yaml
com






#Reference https://greg.jeanmart.me/2020/04/13/self-host-pi-hole-on-kubernetes-and-block-ad/
helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/
helm repo update

# Create Namespace pihole
echo "   Creating Namespace pihole ..."
kubectl create namespace pihole

# Create a secret to store Pi-Hole admin password
echo "   Creating secret for pihole admin ..."
kubectl create secret generic pihole-secret \
  --from-literal='password=VMware12345!' \
  --namespace pihole

# List secret password
echo "   Listing secret password ..."
kubectl get secret pihole-secret --namespace pihole -o jsonpath='{.data.password}' | base64 --decode

# Get Timezone from OVA
TZ=$(timedatectl status | grep "Time zone" | cut -d ":" -f 2 | cut -d " " -f 2)
echo "   Timezone will be $TZ"

# Install Pihole
echo "   Using helm to install pihole ..."
helm install pihole mojo2600/pihole \
  --namespace pihole \
  --values pihole.values.yaml \
  --replace \
  --set TZ=${TZ} 

kubectl get pods -n pihole -o wide
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
  - host: pihole.guarddog.lab
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
