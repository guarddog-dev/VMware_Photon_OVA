#!/bin/bash -x

echo "Building GuardDog AI OVA Appliance ..."
#rm -f output-vmware-iso/*.*
rm -f output-vmware-iso/*.ova

echo "Applying Packer build to photon.pkr.hcl ..."
#packer build -on-error=ask -var-file=photon-builder.json -var-file=photon-version.json photon.json
packer init -upgrade -var-file=photon.variables.pkr.hcl photon.pkr.hcl
packer build -var-file=photon.variables.pkr.hcl photon.pkr.hcl
