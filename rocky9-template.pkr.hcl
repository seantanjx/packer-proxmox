# Variable Definitions
variable "proxmox_api_url" {
    type = string
}

variable "proxmox_api_token_id" {
    type = string
}

variable "proxmox_api_token_secret" {
    type = string
    sensitive = true
}

variable "vm_id" {
    type = string
}

source "proxmox-iso" "rocky-9-template" {
    # proxmox connection configuration
    proxmox_url                 = "${var.proxmox_api_url}"
    username                    = "${var.proxmox_api_token_id}"
    token                       = "${var.proxmox_api_token_secret}"
    insecure_skip_tls_verify    = true

    # VM General configuration
    node                        = "proxmox"
    vm_id                       = "${var.vm_id}"
    vm_name                     = "Rocky-9-template"

    # VM OS configuration
    iso_file                    = "local:iso/Rocky-9.3-x86_64-dvd.iso"
    iso_checksum                = "none"
    iso_storage_pool            = "local"
    template_name               = "rocky-9-template-${var.vm_id}"
    template_description        = "packer generated Rocky-9.3-x86_64-dvd"
    unmount_iso                 = true
    qemu_agent                  = true
    cpu_type                    = "host"


    # VM Hard Disk Settings
    scsi_controller             = "virtio-scsi-pci"
    disks {
        disk_size               = "100G"
        format                  = "qcow2"
        storage_pool            = "local"
    }

    # VM CPU Settings
    cores                       = "4"
    memory                      = "8192"

    # VM Network Settings
    network_adapters {
        model                   = "virtio"
        bridge                  = "vmbr0"
        firewall                = true
    }
    
    # Packer boot commands
    // boot_command = [
    //     "<up>e<down><down><end> inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg network --noipv6 rd.shell<leftCtrlOn>x<leftCtrlOff>"
    // ]
    boot_command = [
        "<tab> text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<enter><wait>"
    ]
    boot_wait                   = "5s"

    # Packer autoinstall settings
    http_directory              = "kickstart"

    # SSH Settings
    ssh_username                = "proxmox"
    ssh_private_key_file        = "~/.ssh/id_ed25519"
    ssh_timeout                 = "15m"

}

# Build Definition to create the VM Template
build {
    sources = ["source.proxmox-iso.rocky-9-template"]

    provisioner "ansible-local" {
        playbook_file = "ansible-packer/playbook.yml"
    }

    provisioner "shell" {
        inline = [
            "sudo apt-get install -y ca-certificates curl gnupg lsb-release",
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
            "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
            "sudo apt-get -y update",
            "sudo apt-get install -y docker-ce docker-ce-cli containerd.io"
        ]
    }
}
