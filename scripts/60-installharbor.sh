#!/bin/bash
# Setup Harbor Registry
echo '> Preparing for Harbor Registry...'

# Versions
CERT_MANAGER_PACKAGE_VERSION=1.8.0
CONTOUR_PACKAGE_VERSION=1.20.1
HARBOR_PACKAGE_VERSION=2.4.2

# Install Cert Manager
echo '> Installing Cert Manager...'
tanzu package install cert-manager --package-name cert-manager.community.tanzu.vmware.com --version ${CERT_MANAGER_PACKAGE_VERSION}

# Install Contour
echo '> Installing Contour...'
tanzu package install contour --package-name contour.community.tanzu.vmware.com --version ${CONTOUR_PACKAGE_VERSION}

# Install Harbor
echo '> Preparing for Harbor Registry...'
echo '> Downloading Harbor Registry files...'
image_url=$(kubectl get packages harbor.community.tanzu.vmware.com.${HARBOR_PACKAGE_VERSION} -o jsonpath='{.spec.template.spec.fetch[0].imgpkgBundle.image}')
imgpkg pull -b $image_url -o /tmp/harbor-package
cp /tmp/harbor-package/config/values.yaml harbor-values.yaml
cp /tmp/harbor-package/config/scripts/generate-passwords.sh .
echo '> Generating Secrets/Passwords for Harbor-values.yaml file...'
bash generate-passwords.sh harbor-values.yaml
#set harbor initial password
echo '> Setting Harbor Admin password to VMware123! in Harbor-values.yaml file...'
sudo sed -i 's/harborAdminPassword:.*/harborAdminPassword: VMware123!/g' harbor-values.yaml
echo '> Removing comments in Harbor-values.yaml file...'
yq -i eval '... comments=""' harbor-values.yaml
echo '> Setting Hostname Harbor-values.yaml file...'
sudo sed -i "s/harbor.yourdomain.com/${HOSTNAME}/g" harbor-values.yaml
echo '> Installing Harbor Registry...'
tanzu package install harbor \
   --package-name harbor.community.tanzu.vmware.com \
   --version ${HARBOR_PACKAGE_VERSION} \
   --values-file harbor-values.yaml
   

