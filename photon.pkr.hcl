packer {
  required_version = ">= 1.7.0"
  
  required_plugins{
  	vsphere = {
  	  version = ">= v1.0.5"
  	  source = "github.com/hashicorp/vmware"
  	}
   }
}

variable "version" {
  type    = string
}

variable "description" {
  type    = string
}

variable "vm_name" {
  type    = string
}

variable "vm_final_name" {
  type    = string
}

variable "iso_checksum" {
  type    = string
}

variable "iso_url" {
  type    = string
}

variable "numvcpus" {
  type    = string
}

variable "ramsize" {
  type    = string
}

variable "guest_username" {
  type    = string
  default = "root"
}

variable "guest_password" {
  type    = string
  default = "VMware12345!"
  // Sensitive vars are hidden from output as of Packer v1.6.5
  sensitive = true
}

variable "builder_host" {
  type    = string
}

variable "builder_host_username" {
  type    = string
}

variable "builder_host_password" {
  type    = string
  default = "VMware1!"
  sensitive = true
}

variable "builder_host_datastore" {
  type    = string
  default = "datastore1"
}

variable "builder_host_portgroup" {
  type    = string
  default = "VM Network"
}

variable "ovftool_deploy_vcenter" {
  type    = string
}

variable "ovftool_deploy_vcenter_password" {
  type    = string
}

variable "ovftool_deploy_vcenter_username" {
  type    = string
  default = "administrator@vsphere.local"
}

variable "photon_ovf_template" {
  type    = string
  default = "photon.xml.template"
}

source "vmware-iso" "vmware-iso" {
  boot_command        = [
  "<esc><wait>", 
  "<enter>", 
  "<enter>", 
  "<enter>", 
  "<down><enter>", 
  "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>", 
  "${var.vm_name}<enter>", 
  "${var.guest_password}<enter>", 
  "${var.guest_password}<enter>", 
  "<enter><wait65>", 
  "<enter><wait45>", 
  "${var.guest_username}<enter>", 
  "${var.guest_password}<enter>", 
  "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config<enter>", 
  "systemctl restart sshd <enter>", 
  "exit <enter>"
  ]
  boot_wait           = "10s"
  disk_size           = "20480"
  format              = "ovf"
  guest_os_type       = "vmware-photon-64"
  headless            = false
  http_directory      = "http"
  insecure_connection = true
  iso_checksum        = "${var.iso_checksum}"
  iso_url             = "${var.iso_url}"
  remote_datastore    = "${var.builder_host_datastore}"
  remote_host         = "${var.builder_host}"
  remote_password     = "${var.builder_host_password}"
  remote_type         = "esx5"
  remote_username     = "${var.builder_host_username}"
  shutdown_command    = "/sbin/shutdown -h now"
  shutdown_timeout    = "1000s"
  ssh_password        = "${var.guest_password}"
  ssh_port            = 22
  ssh_username        = "${var.guest_username}"
  version             = "14"
  vm_name             = "${var.vm_name}"
  vmx_data = {
    annotation                 = "Version: ${var.version}"
    cdrom_type                 = "sata"
    "ethernet0.addressType"    = "generated"
    "ethernet0.networkName"    = "${var.builder_host_portgroup}"
    "ethernet0.present"        = "TRUE"
    "ethernet0.startConnected" = "TRUE"
    "ethernet0.virtualDev"     = "vmxnet3"
    "ethernet0.wakeOnPcktRcv"  = "FALSE"
    firmware                   = "efi"
    memsize                    = "${var.ramsize}"
    numvcpus                   = "${var.numvcpus}"
    "scsi0.virtualDev"         = "pvscsi"
  }
  vnc_over_websocket = true
}

build {
  sources = ["source.vmware-iso.vmware-iso"]

  provisioner "shell" {
    execute_command = "echo ${var.guest_password} | sudo -S bash -c '{{ .Path }}'"
    script          = "scripts/1-installprereqs.sh"
  }

  provisioner "shell" {
    execute_command = "echo ${var.guest_password} | sudo -S bash -c '{{ .Path }}'"
    script          = "scripts/2-setuprc.localservice.sh"
  }

  provisioner "shell" {
    execute_command = "echo ${var.guest_password} | sudo -S bash -c '{{ .Path }}'"
    script          = "scripts/3-installdocker.sh"
  }

  provisioner "shell" {
    execute_command = "echo ${var.guest_password} | sudo -S bash -c '{{ .Path }}'"
    script          = "scripts/4-installtanzutce.sh"
  }

  provisioner "shell" {
    execute_command = "echo ${var.guest_password} | sudo -S bash -c '{{ .Path }}'"
    script          = "scripts/5-installkubectl.sh"
  }

  provisioner "shell" {
    execute_command = "echo ${var.guest_password} | sudo -S bash -c '{{ .Path }}'"
    script          = "scripts/99-hardenos.sh"
  }

  provisioner "shell" {
    execute_command = "echo ${var.guest_password} | sudo -S bash -c '{{ .Path }}'"
    script          = "scripts/100-cleanup.sh"
  }

  provisioner "file" {
    destination = "/root/setup/getOvfProperty.py"
    source      = "files/getOvfProperty.py"
  }

  provisioner "file" {
    destination = "/root/setup/setup.sh"
    source      = "files/setup.sh"
  }

  provisioner "file" {
    destination = "/root/setup/1-setup-os.sh"
    source      = "files/1-setup-os.sh"
  }

  provisioner "file" {
    destination = "/root/setup/2-setup-network.sh"
    source      = "files/2-setup-network.sh"
  }
  
    provisioner "file" {
    destination = "/root/setup/3-install-repo-scripts.sh"
    source      = "files/3-install-repo-scripts.sh"
  }

  provisioner "file" {
    destination = "/root/setup/4-setup-automation.sh"
    source      = "files/4-setup-automation.sh"
  }

  provisioner "file" {
    destination = "/root/setup/resize.sh"
    source      = "files/resize.sh"
  }

  provisioner "file" {
    destination = "/root/automation"
    source      = "automation/"
  }

  post-processor "shell-local" {
    environment_vars = ["PHOTON_VERSION=${var.version}", "PHOTON_APPLIANCE_NAME=${var.vm_name}", "FINAL_PHOTON_APPLIANCE_NAME=${var.vm_final_name}-${var.version}", "PHOTON_OVF_TEMPLATE=${var.photon_ovf_template}"]
    inline           = ["cd manual", "./add_ovf_properties.sh"]
  }
  post-processor "shell-local" {
    inline = ["pwsh -F unregister_vm.ps1 ${var.ovftool_deploy_vcenter} ${var.ovftool_deploy_vcenter_username} ${var.ovftool_deploy_vcenter_password} ${var.vm_name}"]
  }
}
