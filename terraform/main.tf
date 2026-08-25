resource "proxmox_vm_qemu" "dns" {
  name        = "srv-dns-01"
  target_node = "pve"

  clone      = "ubuntu-template"
  full_clone = true

  memory = 1024
  agent  = 1
  onboot = true
  scsihw = "virtio-scsi-pci"

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
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = "vmbr0"
  }

  os_type   = "cloud-init"
  ipconfig0 = "ip=192.168.18.11/24,gw=192.168.18.1"
  ciuser    = "devops"

  sshkeys = file(pathexpand("~/.ssh/id_ed25519_homelab.pub"))
}