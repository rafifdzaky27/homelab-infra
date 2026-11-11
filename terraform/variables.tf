# variables.tf - nilai jaringan dan akses TIDAK ditulis di repo publik.
# Salin terraform.tfvars.example menjadi network.auto.tfvars (atau terraform.tfvars) dan isi nilai aslinya.
# Kedua nama itu ada di .gitignore. Token: export TF_VAR_pm_token=... (jangan taruh di berkas).
variable "pm_token" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "pm_api_url" {
  description = "URL API Proxmox, mis. https://<proxmox-ip>:8006/api2/json"
  type        = string
}

variable "pm_token_id" {
  description = "ID API token Proxmox, format user@realm!nama-token"
  type        = string
}

variable "pm_node" {
  description = "Nama node Proxmox tempat VM dan LXC dibuat"
  type        = string
}

variable "gateway_ip" {
  description = "Gateway LAN untuk semua VM dan LXC"
  type        = string
}

variable "vm_ips" {
  description = "IP statis per guest. Kunci: dns, dns2, vpn, wg, proxy, fitness, opengym, pitwall, jellyfin_private, jellyfin_shared"
  type        = map(string)
}
