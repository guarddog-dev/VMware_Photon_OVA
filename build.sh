#!/bin/bash -x

echo "Building GuardDog AI OVA Appliance ..."
rm -f output-vmware-iso/*.*

echo "Applying Packer build to ubuntu-builder.json ..."
packer build -on-error=ask -var-file=photon-builder.json -var-file=photon-version.json photon.json

