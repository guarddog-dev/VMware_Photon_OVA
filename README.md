## Packer config to build Vsphere virtual machines templates from Photon OS ISO file as a source.


## Prior to first run:
1. Configure the variables in ubuntu-20.04.json. If you wish to change the USERD variable from administrator, you will also need to update many of the shell script files with the updated user account (USERD=[xx]).
Note: Do not put any capital letters in the name of the VM if you change the vm name, as this will cause the install to fail.

2. Configure the variables in the ubuntu-builder.json. 

3. Configure the variables in the ubuntu-version.json.

4. Enable SSH on the host you will be building with. Packer will work directly with that host (does not require a VCSA).

5. Set the Net.GuestIPHack setting on the ESXi host. This will allow packer to VNC to the host and input the commands needed during the inital OS deployment. Post deployment of the OS packer will use SSH.
#### CLI Method:
>esxcli system settings advanced set -o /Net/GuestIPHack -i 1
#### PowerCLI Method:
>pswd #only needed for MacOS or Linux

>$VMHOST = Read-Host "Please input the IP or FQDN of your ESXi Host"

>$CREDs = Get-Credential -Message "Please provide the root user name and password to the ESXi Host"

>Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

>connect-viserver $VMHOST -credential $CREDS

>Get-AdvancedSetting -Name Net.GuestIPHack -Entity $VMHOST

>Set-AdvancedSetting -Name Net.GuestIPHack -Value 1 -Entity $VMHOST

>Get-AdvancedSetting -Name Net.GuestIPHack -Entity $VMHOST

6. Update the Ubuntu ISO URL/Checksums with newer versions if needed. If you wish to do this, you will also likely need to update the ubuntu-20.04.json "boot_command" section for the updated OS version.

7. Install ovftool, git-all, powershell, and packer utilities.
#### Due to requirements, it is recommended to build this OVA from a Ubuntu Linux desktop with a GUI.
#### Download the ovftool from VMware Developer (get the lastest version). This will require a standard browser like Firefox or Chromium.
https://developer.vmware.com/web/tool/4.4.0/ovf
#### Extract
>sudo ./VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle --extract ovftool && cd ovftool
#### Unzip
>sudo unzip VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle
#### setup scripting to be runable
>chmod a+x VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle
#### Install ovftool
>sudo ./VMware-ovftool-4.4.3-18663434-lin.x86_64.bundle
#### install Packer
>sudo apt-get install -y packer
#### install powershell
>sudo apt-get install -y powershell
#### install git-all
>sudo apt install -y git-all
>git --version

8. Clone this repository to your Linux Desktop 
#### Download repository to your Linux computer/VM
>git clone "https site for git repository"

#### Note: 
The VCSA variables are only needed to remove the orphaned VM object post completion from the VCSA. If you dont wish to use a VCSA for this, simply put the host name/IP, and login creds in place of the VCSA info.

#### Note2:
Packer will open a random HTTP port from 8000 to 9000 as part of the packer build process. It may be necessary to open the port range on your Linux Desktop: sudo ufw allow 8000:9000/tcp

## Run packer build:
>./build.sh

## Build Time:
Approximately 45 minutes depending upon internet/network connectivity/CPU/drive speed.

## Troubleshooting
The most common problem I have run into is not having enough wait time set for the OS to complete inital installation. This is dependant on the internet and your network since Ubuntu likes to download/install security updates as part of the OS deployment process. If the time is not long enough, your OS will not complete the install prior to the rest of the VNC keyboard commands being run, causing everything to fail. If you need to tweak this, simply move up by increments of 30 seconds until you find the sweet spot. To set this, simply open the ubuntu-20.04.json and update the line (34 presently) "<tab><enter><wait500>" from 500 to 530 or 600.

## Reference Website info on Packer for VMware
https://packer.io/plugins/builders/vmware/iso
