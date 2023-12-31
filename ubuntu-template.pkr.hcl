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

source "proxmox-iso" "ubuntu-server-jammy-template" {
    # proxmox connection configuration
    proxmox_url                 = "${var.proxmox_api_url}"
    username                    = "${var.proxmox_api_token_id}"
    token                       = "${var.proxmox_api_token_secret}"
    insecure_skip_tls_verify    = true

    # VM General configuration
    node                        = "proxmox"
    vm_id                       = "${var.vm_id}"
    vm_name                     = "ubuntu-22.04.3-template"

    # VM OS configuration
    iso_file                    = "local:iso/ubuntu-22.04.3-live-server-amd64.iso" #https://releases.ubuntu.com/jammy/SHA256SUMS
    iso_checksum                = "none"
    iso_storage_pool            = "local"
    template_name               = "ubuntu-server-jammy-template-${var.vm_id}"
    template_description        = "packer generated ubuntu-20.04.3-server-amd64"
    unmount_iso                 = true
    qemu_agent                  = true


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

    # Cloud-init Settings
    cloud_init                  = true
    cloud_init_storage_pool     = "local"
    
    # Packer boot commands
    boot_command = [
        "<esc><wait>",
        "e<wait>",
        "<down><down><down><end>",
        "<bs><bs><bs><bs><wait>",
        "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
        "<f10><wait>"
    ]
    boot                        = "c"
    boot_wait                   = "5s"

    # Packer autoinstall settings
    http_directory              = "http"

    # SSH Settings
    ssh_username                = "proxmox"
    ssh_private_key_file        = "~/.ssh/id_ed25519"
    ssh_timeout                 = "10m"

}

# Build Definition to create the VM Template
build {
    name = "ubuntu-server-jammy"
    sources = ["source.proxmox-iso.ubuntu-server-jammy-template"]

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
    provisioner "shell" {
        inline = [
            "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
            "sudo rm /etc/ssh/ssh_host_*",
            "sudo truncate -s 0 /etc/machine-id",
            "sudo apt -y autoremove --purge",
            "sudo apt -y clean",
            "sudo apt -y autoclean",
            "sudo cloud-init clean",
            "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
            "sudo rm -f /etc/netplan/00-installer-config.yaml",
            "sudo sync"
        ]
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
    provisioner "file" {
        source = "files/99-pve.cfg"
        destination = "/tmp/99-pve.cfg"
    }

    # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
    provisioner "shell" {
        inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
    }

    # Provisioning the VM Template with Docker Installation #4
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
