locals {
  jellyfin_nodes = {
    private = {
      vmid     = 201
      hostname = "srv-media-private"
      ip       = var.vm_ips["jellyfin_private"]
    }
    shared = {
      vmid     = 202
      hostname = "srv-media-shared"
      ip       = var.vm_ips["jellyfin_shared"]
    }
  }
}

resource "proxmox_lxc" "jellyfin" {
  for_each        = local.jellyfin_nodes
  vmid            = each.value.vmid
  hostname        = each.value.hostname
  target_node     = var.pm_node
  ostemplate      = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  unprivileged    = true
  start           = true
  onboot          = true
  cores           = 4
  memory          = 2048
  swap            = 512
  ssh_public_keys = file(pathexpand("~/.ssh/id_ed25519_homelab.pub"))

  rootfs {
    storage = "local-lvm"
    size    = "16G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "${each.value.ip}/24"
    gw     = var.gateway_ip
  }

  lifecycle {
    ignore_changes = [tags]
  }
}