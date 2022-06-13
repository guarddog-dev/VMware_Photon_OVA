#!/bin/bash
# Setup Velero
echo '> Preparing for Velero backup/restore package...'

# Versions
VELERO_PACKAGE_VERSION=1.8.0

# Create Unmanaged Cluster
echo '> Creating Unmanaged Cluster...'
tanzu um create local-cluster -p 80:80 -p 443:443 -c calico

# Install Velero
echo '> Installing Velero...'
# https://tanzucommunityedition.io/docs/v0.12/package-readme-cert-manager-1.8.0/
tanzu package available list velero.community.tanzu.vmware.com
tanzu package install velero --package-name velero.community.tanzu.vmware.com --version ${VELERO_PACKAGE_VERSION}

