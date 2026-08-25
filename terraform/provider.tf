terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc04"
    }
  }
}

provider "proxmox" {
  pm_api_url          = "https://192.168.18.10:8006/api2/json"
  pm_api_token_id     = "terraform@pve!tftoken"
  pm_api_token_secret = var.pm_token
  pm_tls_insecure     = true
}