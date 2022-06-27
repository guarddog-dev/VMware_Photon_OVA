#!/bin/bash

# clean up just in case
#rm -f photon.xml

OUTPUT_PATH="../output-vmware-iso"
OVF_PATH=$(find ${OUTPUT_PATH} -type f -iname ${PHOTON_APPLIANCE_NAME}.ovf -exec dirname "{}" \;)

# Move ovf files in to a subdirectory of OUTPUT_PATH if not already
if [ "${OUTPUT_PATH}" = "${OVF_PATH}" ]; then
    mkdir ${OUTPUT_PATH}/${PHOTON_APPLIANCE_NAME}
    mv ${OUTPUT_PATH}/*.* ${OUTPUT_PATH}/${PHOTON_APPLIANCE_NAME}
    OVF_PATH=${OUTPUT_PATH}/${PHOTON_APPLIANCE_NAME}
fi

rm -f ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.mf

#clone xml template
cp photon.xml.template photon.xml

##Comment out next section for no automation
# Import list of Automation Shell Scripts into OVA Automation List
echo "> Exporting Automation Shells Scripts to a list for OVA use..."
#rm array_list.txt
SCRIPTS_PATH="../automation"
SCRIPT_LIST=$(ls $SCRIPTS_PATH | tr ' ' '.' | rev | cut -c 4- | rev)
SCRIPT_ARRAY=( $SCRIPT_LIST )
FIRST_SCRIPT=${SCRIPT_ARRAY[0]}
BEG="&quot;"
END="&quot;, "
#output array to text file
#touch array_list.txt
for i in ${SCRIPT_ARRAY[@]}; do echo $BEG$i$END >> array_list.txt; done
#remove comma from last line
sed -i '$ s/.$//' array_list.txt
#import txt as array
readarray -t TEMP < array_list.txt
#Echo array to single string list
SCRIPTSLIST=$(echo ${TEMP[@]})
perl -i -pe  "s/SCRIPTSLISTVAR/${SCRIPTSLIST}/g" photon.xml
sed -i "s/FIRSTSCRIPTVAR/${FIRST_SCRIPT}/g" photon.xml
rm array_list.txt

#update Photon Version Info
sed -i "s/{{VERSION}}/${PHOTON_VERSION}/g" photon.xml

if [ "$(uname)" == "Darwin" ]; then
    sed -i .bak1 's/<VirtualHardwareSection>/<VirtualHardwareSection ovf:transport="com.vmware.guestInfo">/g' ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
    sed -i .bak2 "/    <\/vmw:BootOrderSection>/ r photon.xml" ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
    sed -i .bak3 '/^      <vmw:ExtraConfig ovf:required="false" vmw:key="nvram".*$/d' ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
    sed -i .bak4 "/^    <File ovf:href=\"${PHOTON_APPLIANCE_NAME}-file1.nvram\".*$/d" ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
    sed -i .bak5 '/vmw:ExtraConfig.*/d' ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
else
    sed -i 's/<VirtualHardwareSection>/<VirtualHardwareSection ovf:transport="com.vmware.guestInfo">/g' ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
    sed -i "/    <\/vmw:BootOrderSection>/ r photon.xml" ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
    sed -i '/^      <vmw:ExtraConfig ovf:required="false" vmw:key="nvram".*$/d' ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
    sed -i "/^    <File ovf:href=\"${PHOTON_APPLIANCE_NAME}-file1.nvram\".*$/d" ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
    sed -i '/vmw:ExtraConfig.*/d' ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf
fi

#ovftool ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf ${OUTPUT_PATH}/${FINAL_PHOTON_APPLIANCE_NAME}.ova
ovftool --eula@=eula.txt ${OVF_PATH}/${PHOTON_APPLIANCE_NAME}.ovf ${OUTPUT_PATH}/${FINAL_PHOTON_APPLIANCE_NAME}.ova
#mv ${OVF_PATH}/${FINAL_PHOTON_APPLIANCE_NAME}.ova ${OUTPUT_PATH}/${FINAL_PHOTON_APPLIANCE_NAME}.ova 

rm -rf ${OVF_PATH}/*.ovf
rm -rf ${OVF_PATH}/*.vmdk
rm -rf ${OVF_PATH}/*.nvram
rm -rf ${OVF_PATH}
rm -f photon.xml
