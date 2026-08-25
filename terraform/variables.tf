# variables.tf - deklarasikan token, jangan hardcode di provider.tf
variable "pm_token" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}
