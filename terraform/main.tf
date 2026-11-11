resource "proxmox_vm_qemu" "dns" {
  name        = "srv-dns-01"
  target_node = var.pm_node

  clone      = "ubuntu-template"
  full_clone = true

  memory = 1024
  agent  = 1
  onboot = true
  scsihw = "virtio-scsi-pci"

  lifecycle {
    ignore_changes = [tags]
  }

  cpu {
    cores = 1
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  disk {
    slot    = "scsi0"
    size    = "16G"
    type    = "disk"
    storage = "local-lvm"
    format  = "raw"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  os_type   = "cloud-init"
  ipconfig0 = "ip=${var.vm_ips["dns"]}/24,gw=${var.gateway_ip}"
  ciuser    = "devops"

  sshkeys = file(pathexpand("~/.ssh/id_ed25519_homelab.pub"))
}


resource "proxmox_vm_qemu" "dns2" {
  name        = "srv-dns-02"
  target_node = var.pm_node

  clone      = "ubuntu-template"
  full_clone = true

  memory = 768
  agent  = 1
  onboot = true
  scsihw = "virtio-scsi-pci"

  lifecycle {
    ignore_changes = [tags]
  }

  cpu {
    cores = 1
    type  = "host"
  }

  # Cloud-init HARUS dulu supaya Telmate state ordering stabil
  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  disk {
    slot    = "scsi0"
    size    = "16G"
    storage = "local-lvm"
    type    = "disk"
    format  = "raw"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  os_type   = "cloud-init"
  ipconfig0 = "ip=${var.vm_ips["dns2"]}/24,gw=${var.gateway_ip}"

  ciuser  = "devops"
  sshkeys = file(pathexpand("~/.ssh/id_ed25519_homelab.pub"))
}


resource "proxmox_vm_qemu" "vpn_gw" {
  name        = "srv-vpn-01"
  target_node = var.pm_node
  clone       = "ubuntu-template"

  memory = 512
  agent  = 1
  onboot = true
  scsihw = "virtio-scsi-pci"

  lifecycle {
    ignore_changes = [tags]
  }

  cpu {
    cores = 1
    type  = "host"
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  disk {
    slot    = "scsi0"
    size    = "8G"
    storage = "local-lvm"
    type    = "disk"
    format  = "raw"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  os_type   = "cloud-init"
  ipconfig0 = "ip=${var.vm_ips["vpn"]}/24,gw=${var.gateway_ip}"
  ciuser    = "devops"

  sshkeys = file(pathexpand("~/.ssh/id_ed25519_homelab.pub"))
}


resource "proxmox_vm_qemu" "wg" {
  name        = "srv-wg-01"
  target_node = var.pm_node
  clone       = "ubuntu-template"

  memory = 512
  agent  = 1
  onboot = true
  scsihw = "virtio-scsi-pci"

  lifecycle {
    ignore_changes = [tags]
  }

  cpu {
    cores = 1
    type  = "host"
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  disk {
    slot    = "scsi0"
    size    = "8G"
    storage = "local-lvm"
    type    = "disk"
    format  = "raw"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  os_type   = "cloud-init"
  ipconfig0 = "ip=${var.vm_ips["wg"]}/24,gw=${var.gateway_ip}"
  ciuser    = "devops"

  sshkeys = file(pathexpand("~/.ssh/id_ed25519_homelab.pub"))
}


resource "proxmox_vm_qemu" "proxy" {
  name        = "srv-proxy-01"
  target_node = var.pm_node

  clone      = "ubuntu-template"
  full_clone = true

  memory = 512
  agent  = 1
  onboot = true
  scsihw = "virtio-scsi-pci"

  lifecycle {
    ignore_changes = [tags]
  }

  cpu {
    cores = 1
    type  = "host"
  }

  disk {
    slot    = "ide2"
    type    = "cloudinit"
    storage = "local-lvm"
  }

  disk {
    slot    = "scsi0"
    size    = "12G"
    storage = "local-lvm"
    type    = "disk"
    format  = "raw"
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  os_type   = "cloud-init"
  ipconfig0 = "ip=${var.vm_ips["proxy"]}/24,gw=${var.gateway_ip}"
  ciuser    = "devops"

  sshkeys = file(pathexpand("~/.ssh/id_ed25519_homelab.pub"))
}