# opengym.tf - openGym Docker host, public via its own Cloudflare Tunnel
resource "proxmox_vm_qemu" "opengym" {
  name        = "srv-gym-01"
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
    cores = 2
    type  = "host"
  }

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
  ipconfig0 = "ip=${var.vm_ips["opengym"]}/24,gw=${var.gateway_ip}"
  ciuser    = "devops"

  sshkeys = file(pathexpand("~/.ssh/id_ed25519_homelab.pub"))
}
