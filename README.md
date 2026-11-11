# homelab-infra

Infrastructure as Code untuk homelab pribadi di atas Proxmox: **Terraform** membuat VM dan LXC, **Ansible** mengonfigurasinya, dan `docs/` berisi runbook layanan. (English: Terraform + Ansible for a personal Proxmox homelab, with per-service runbooks.)

Repo ini publik. Alamat jaringan, nama host internal, dan rahasia **tidak** ada di sini; semuanya berupa placeholder atau berada di berkas lokal yang diabaikan git.

## Isi

| Folder | Fungsi |
|---|---|
| `terraform/` | VM dan LXC Proxmox (DNS, proxy, VPN, media, aplikasi) lewat provider Telmate/proxmox |
| `ansible/` | Role dan playbook: `common`, `docker`, `caddy`, `adguard`, `jellyfin`, backup terjadwal, dan host aplikasi |
| `docs/` | Runbook: Caddy, SparkyFitness, openGym |

## Nilai lokal (tidak di-commit)

Nilai asli ditaruh di berkas yang tercantum di `.gitignore`. Versi contohnya (placeholder RFC 5737, `192.0.2.0/24`) ada di repo.

| Berkas lokal | Contoh di repo | Isi |
|---|---|---|
| `terraform/network.auto.tfvars` | `terraform/terraform.tfvars.example` | URL API, ID token, nama node, gateway, IP tiap guest |
| `ansible/inventory.local.ini` | `ansible/inventory.example.ini` | Host dan IP, user SSH, jalur kunci SSH |
| `ansible/group_vars/all/zz-local.yml` | `ansible/group_vars/all/network.yml` | Domain internal, CIDR LAN, host di belakang reverse proxy |
| `ansible/group_vars/gym/zz-local.yml` | (komentar di `group_vars/gym/main.yml`) | UID admin aplikasi |

Berkas `zz-local.yml` sengaja dinamai `zz-` karena Ansible memuat berkas `group_vars` berurutan menurut nama dan yang terakhir menang, jadi nilai lokal menimpa placeholder.

### Terraform

```bash
cp terraform/terraform.tfvars.example terraform/network.auto.tfvars   # lalu isi nilai asli
export TF_VAR_pm_token='...'                                          # rahasia lewat env, bukan berkas
cd terraform && terraform init && terraform plan
```

### Ansible (dari WSL)

```bash
cp ansible/inventory.example.ini ansible/inventory.local.ini          # lalu isi IP asli
export ANSIBLE_CONFIG=$PWD/ansible/ansible.cfg                        # folder /mnt/c world-writable, tanpa ini ansible.cfg diabaikan
ansible-galaxy collection install -r ansible/requirements.yml
ansible-playbook ansible/playbooks/caddy.yml --check --diff --ask-vault-pass
```

## Rahasia

Rahasia disimpan dengan **ansible-vault** (`group_vars/*/vault.yml`, `pihole_vault.yml`; nilainya terenkripsi). Token Proxmox tidak pernah ditulis ke berkas. State Terraform (`*.tfstate`) dan rencana (`*.tfplan`) diabaikan git. Berkas `*.example` hanya berisi placeholder.

## Yang sengaja publik

Domain publik (`rafifdzaky.com` dan subdomainnya) dan kunci publik SSH untuk deploy (`pitwall_deploy.pub`) memang terbuka; keduanya tidak memberi akses ke jaringan rumah.
