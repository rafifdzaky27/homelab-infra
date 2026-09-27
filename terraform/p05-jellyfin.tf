locals {
  jellyfin_nodes = {
    private = {
      vmid     = 201
      hostname = "srv-media-private"
      ip       = "192.168.18.13"
    }
    shared = {
      vmid     = 202
      hostname = "srv-media-shared"
      ip       = "192.168.18.26"
    }
  }
}

resource "proxmox_lxc" "jellyfin" {
  for_each        = local.jellyfin_nodes
  vmid            = each.value.vmid
  hostname        = each.value.hostname
  target_node     = "pve"
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
    gw     = "192.168.18.1"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}