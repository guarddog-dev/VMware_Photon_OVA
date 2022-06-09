#!/bin/bash
# Setup Harbor Registry
echo '> Preparing for Harbor Registry...'

# Versions
CERT_MANAGER_PACKAGE_VERSION=1.8.0
CONTOUR_PACKAGE_VERSION=1.20.1
HARBOR_PACKAGE_VERSION=2.4.2

# Create Unmanaged Cluster
echo '> Creating Unmanaged Cluster...'
tanzu um create local-cluster -p 80:80 -p 443:443 -c calico

# Install Cert Manager
echo '> Installing Cert Manager...'
# https://tanzucommunityedition.io/docs/v0.12/package-readme-cert-manager-1.8.0/
tanzu package install cert-manager --package-name cert-manager.community.tanzu.vmware.com --version ${CERT_MANAGER_PACKAGE_VERSION}

# Install Contour
echo '> Installing Contour...'
# https://tanzucommunityedition.io/docs/v0.12/package-readme-contour-1.20.1/
cat <<EOF >contour-values.yaml
envoy:
  service:
    type: ClusterIP
EOF
tanzu package install contour \
  --package-name contour.community.tanzu.vmware.com \
  --version ${CONTOUR_PACKAGE_VERSION} \
  --values-file contour-values.yaml
rm contour-values.yaml

# Install Harbor
echo '> Preparing for Harbor Registry...'
# https://tanzucommunityedition.io/docs/v0.12/package-readme-harbor-2.4.2/
echo '> Downloading Harbor Registry files...'
image_url=$(kubectl get packages harbor.community.tanzu.vmware.com.${HARBOR_PACKAGE_VERSION} -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
imgpkg pull -b $image_url -o /tmp/harbor-package
cp /tmp/harbor-package/config/values.yaml harbor-values.yaml
cp /tmp/harbor-package/config/scripts/generate-passwords.sh .
echo '> Generating Secrets/Passwords for Harbor-values.yaml file...'
bash generate-passwords.sh harbor-values.yaml
#set harbor initial password
#echo '> Setting Harbor Admin password to VMware123! in Harbor-values.yaml file...'
HARBOR_ADMIN_PASSWORD="VMware12345!"
sudo sed -i "s/harborAdminPassword:.*/harborAdminPassword: ${HARBOR_ADMIN_PASSWORD}/g" harbor-values.yaml
SET_HARBOR_ADMIN_PASSWORD=$(less harbor-values.yaml | grep harborAdminPassword)
echo "Harbor Admin Password will be $SET_HARBOR_ADMIN_PASSWORD"
echo '> Removing comments in Harbor-values.yaml file...'
yq -i eval '... comments=""' harbor-values.yaml
#echo '> Setting Hostname Harbor-values.yaml file...'
#sudo sed -i "s/harbor.yourdomain.com/${HOSTNAME}/g" harbor-values.yaml
echo '> Updating /etc/hosts with harbor info...'
echo "$IPADDRS harbor.yourdomain.com notary.harbor.yourdomain.com" >> /etc/hosts
echo '> Installing Harbor Registry...'
tanzu package install harbor \
   --package-name harbor.community.tanzu.vmware.com \
   --version ${HARBOR_PACKAGE_VERSION} \
   --values-file harbor-values.yaml

#Open Ports
echo -e '> Opening standard Harbor Ports...'
sudo iptables -I INPUT -p tcp -m tcp --dport 4318 -j ACCEPT
sudo iptables -I INPUT -p tcp -m tcp --dport 14268 -j ACCEPT
sudo iptables -I INPUT -p tcp -m tcp --dport 8001 -j ACCEPT
sudo iptables -I INPUT -p tcp -m tcp --dport 443 -j ACCEPT
sudo iptables-save

