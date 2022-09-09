#!/bin/bash -x

echo "Building GuardDog Tanzu Community Edition OVA Appliance ..."
#rm -f output-vmware-iso/*.*
rm -rfv output-vmware-iso/*

echo "Applying Packer build to photon.pkr.hcl ..."
#packer build -on-error=ask -var-file=photon-builder.json -var-file=photon-version.json photon.json
packer init -upgrade -var-file=photon.variables.pkr.hcl photon.pkr.hcl
packer build -var-file=photon.variables.pkr.hcl photon.pkr.hcl
