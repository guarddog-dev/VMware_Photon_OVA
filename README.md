## OVA Appliance for Tanzu Community Edition with Packer config based on PhotonOS

#### Framework from this project came from William Lam's Harbor project. You can find it here:
https://github.com/lamw/harbor-appliance

## Click below to download the OVA:
https://github.com/guarddog-dev/VMware_Photon_OVA/tree/main/output-vmware-iso

## Prior to first run:
#### Due to requirements, it is recommended to build this OVA from a Ubuntu Linux desktop with a GUI.
1. Configure the variables in photon.variables.pkr.hcl. If you wish to change the USERD variable from administrator, you will also need to update many of the shell script files with the updated user account (USERD=[xx]).
Note: Do not put any capital letters in the name of the VM if you change the vm name, as this will cause the install to fail.

2. Configure the variables in the photon.variables.pkr.hcl 

3. Enable SSH on the host you will be building with. Packer will work directly with that host (does not require a VCSA).

4. Set the Net.GuestIPHack setting on the ESXi host. This will allow packer to VNC to the host and input the commands needed during the inital OS deployment. Post deployment of the OS packer will use SSH.
#### CLI Method:
>esxcli system settings advanced set -o /Net/GuestIPHack -i 1
#### PowerCLI Method:
>pwsh #only needed for MacOS or Linux

>$VMHOST = Read-Host "Please input the IP or FQDN of your ESXi Host"

>$CREDs = Get-Credential -Message "Please provide the root user name and password to the ESXi Host"

>Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

>connect-viserver $VMHOST -credential $CREDS

>Get-AdvancedSetting -Name Net.GuestIPHack -Entity $VMHOST

>Get-AdvancedSetting -Name Net.GuestIPHack -Entity $VMHOST| Set-AdvancedSetting -Value 1

>Get-AdvancedSetting -Name Net.GuestIPHack -Entity $VMHOST

5. Update the Photon ISO URL/Checksums with newer versions if needed. If you wish to do this, you will also likely need to update the photon.json "boot_command" section for the updated OS version.

6. Install ovftool, git-all, powershell, and packer utilities.

#### Download the ovftool from VMware Developer (get the lastest version). This will require a standard browser like Firefox or Chromium.
https://developer.vmware.com/web/tool/4.4.0/ovf
#### setup scripting to be runable
>chmod a+x VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle
#### Install ovftool
>sudo ./VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle
#### install Packer
https://learn.hashicorp.com/tutorials/packer/get-started-install-cli
#### install powershell
https://docs.microsoft.com/en-us/powershell/scripting/install/install-ubuntu?view=powershell-7.2
#### install git-all
>sudo apt install -y git-all
>git --version

7. Clone this repository to your Linux Desktop 
#### Download repository to your Linux computer/VM
>git clone "https site for git repository"

#### Note: 
The VCSA variables are only needed to remove the orphaned VM object post completion from the VCSA. If you dont wish to use a VCSA for this, simply put the host name/IP, and login creds in place of the VCSA info.

#### Note2:
Packer will open a random HTTP port from 8000 to 9000 as part of the packer build process. It may be necessary to open the port range on your Linux Desktop: sudo ufw allow 8000:9000/tcp

## Run packer build:
>./build.sh

## Build Time:
Approximately 15 minutes depending upon internet/network connectivity/CPU/drive speed.

## Troubleshooting
The most common problem I have run into is not having enough wait time set for the OS to complete inital installation. If the time is not long enough, your OS will not complete the install prior to the rest of the VNC keyboard commands being run, causing everything to fail. If you need to tweak this, simply move up by increments of 30 seconds until you find the sweet spot. To set this, simply open the photon.pkr.hcl and update the line (109 presently) "<enter><wait65>", from 65 to 90.

## Reference Website info on Packer for VMware
https://packer.io/plugins/builders/vmware/iso

#### Please deploy to ESXi or VMware vSphere. Testing has been completed to verify that all guest customizations/automation work with this method for ESXi 6.7+ and vSphere 6.7+.

#### If deploying to VMware Workstation or other virtualization environments, guest customizations will not function. Root password will default to VMware12345!@#$% and will use DHCP for its network configuration.
