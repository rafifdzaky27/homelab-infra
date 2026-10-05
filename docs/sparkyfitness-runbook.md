# Runbook: SparkyFitness di srv-fit-01

VM `srv-fit-01` (192.168.18.27). URL `https://fit.rafifdzaky.com`, hanya internal.
Jalur: iPhone → Tailscale → Caddy (.14) → VM .27 port 3004.

Semua perintah dijalankan dari clone repo ini. Terraform di PowerShell, Ansible di WSL.

## 0. Ambil branch
```powershell
git fetch origin
git checkout feat/sparkyfitness-srv-fit-01
```

## 1. Cek tag image (wajib sebelum apply)
Buka Docker Hub dan pastikan dua tag ini ada:
- `codewithcj/sparkyfitness_server:v1.7.3`
- `codewithcj/sparkyfitness:v1.7.3`

Kalau format tag beda, ubah `sparky_version` di `ansible/roles/sparky_host/defaults/main.yml`.
Cek juga compose resmi SparkyFitness. Bandingkan nama variabel env dengan
`ansible/roles/sparky_host/templates/docker-compose.yml.j2`.

## 2. Buat VM (Terraform, PowerShell)
```powershell
cd terraform
terraform plan
```
Expected: hanya `proxmox_vm_qemu.fitness` yang ditambah. Tidak ada VM lain yang berubah.
Kalau ada perubahan lain, berhenti dan kirim outputnya.
```powershell
terraform apply
```
Verify: `ssh devops@192.168.18.27` berhasil.

## 3. Buat secret (WSL)
```bash
cd ansible
cp group_vars/fitness/vault.yml.example group_vars/fitness/vault.yml
openssl rand -hex 32                                   # api encryption key, 64 hex
openssl rand -hex 32                                   # better auth secret
openssl rand -base64 36 | tr -d '/+=' | cut -c1-40     # tiap password (3 kali)
nano group_vars/fitness/vault.yml
ansible-vault encrypt group_vars/fitness/vault.yml
```
Isi `sparky_admin_email` dengan email loginmu.
Simpan semua secret ini juga di password manager. `BETTER_AUTH_SECRET` dan API key tidak boleh berubah setelah dipakai.
Repo ini publik. Pastikan `vault.yml` sudah terenkripsi (baris pertama `$ANSIBLE_VAULT`) sebelum `git add`.

## 3b. Deploy VM (Ansible)
```bash
ansible-playbook playbooks/fitness.yml --ask-vault-pass --check --diff
ansible-playbook playbooks/fitness.yml --ask-vault-pass
```
Verify di VM:
```bash
ssh devops@192.168.18.27
docker ps                      # 3 container Up, db healthy
sudo iptables -S DOCKER-USER   # ada aturan DROP untuk port 3004
```

## 4. DNS
- AdGuard (.11): `ansible-playbook playbooks/adguard.yml --ask-vault-pass`. Template sudah punya rewrite `fit.rafifdzaky.com` → 192.168.18.14.
- Pi-hole (.12): tambah manual di Local DNS Records: `fit.rafifdzaky.com` → `192.168.18.14`. Harus sama dengan AdGuard.
- Jangan buat record publik di Cloudflare dan jangan buat wildcard `*.rafifdzaky.com` di DNS lokal.

## 5. Caddy
```bash
ansible-playbook playbooks/caddy.yml --ask-vault-pass
```
Verify (dari PC, lewat LAN atau Tailscale):
```bash
dig +short fit.rafifdzaky.com @192.168.18.11     # 192.168.18.14
dig +short fit.rafifdzaky.com @192.168.18.12     # 192.168.18.14
curl -I https://fit.rafifdzaky.com               # 200, sertifikat valid
```

## 6. Tes negatif (wajib)
Dari PC (bukan .14), port 3004 harus ditolak:
```bash
curl -m 5 http://192.168.18.27:3004     # harus timeout
```
Dari srv-proxy-01, harus tembus:
```bash
curl -I http://192.168.18.27:3004       # 200
```
Dari luar jaringan tanpa Tailscale, `https://fit.rafifdzaky.com` tidak boleh bisa diakses.

## 7. Akun pertama
1. Buka `https://fit.rafifdzaky.com`, daftar dengan email admin.
2. Ubah `sparky_disable_signup: true` di `ansible/group_vars/fitness/main.yml`.
3. Jalankan ulang `ansible-playbook playbooks/fitness.yml --ask-vault-pass`.
4. Cek bahwa halaman daftar tertutup.

## 8. iPhone
1. Pastikan Tailscale aktif.
2. Install app SparkyFitness dari App Store.
3. Isi server URL `https://fit.rafifdzaky.com`, login.
4. Aktifkan sinkron Apple Health. Beri izin berat badan dan langkah.

## 9. Data awal
Isi profil, target 79.9 kg pada 25 Nov 2026, lalu input berat dari tracker:
19 Sep 89.2, 20 Sep 89.1, 26 Sep 88.3, 27 Sep 87.35, 28 Sep 87.8, 3 Okt 87.95, 4 Okt 87.05, 5 Okt 87.0.
Lingkar perut: 25 Sep 103.5, 27 Sep 97, 5 Okt 100.

## 10. Uji backup
```bash
ssh devops@192.168.18.27
sudo systemctl start sparky-backup.service && journalctl -u sparky-backup -n 20
restic -r /var/backups/sparky-restic --password-file /etc/sparky-backup/restic-password snapshots
sudo systemctl start sparky-restore-test.service && journalctl -u sparky-restore-test -n 20
```
Expected: `backup ok` dan `restore test ok`.
Backup offsite (GDrive) belum aktif. Isi `sparky_backup_offsite_repo` setelah rclone remote siap.

## Rollback
```bash
ssh devops@192.168.18.27 "cd /opt/sparky && docker compose down"
```
Hapus blok `fit.rafifdzaky.com` dari Caddyfile, jalankan ulang `caddy.yml`.
Hapus VM: hapus `terraform/fitness.tf`, lalu `terraform apply`. Data di VM ikut hilang, jadi simpan backup dulu.

## Catatan terbuka
- RAM VM 2048 MB. Cek ke tabel RAM playbook sebelum apply.
- Rewrite AdGuard lama `*.home.arpa` menjawab `192.168.1.14`, bukan `192.168.18.14`. Mungkin typo atau subnet lama. Tidak diubah di PR ini.
- Nama env dan path volume diambil dari compose upstream yang belum kuverifikasi langsung dari server. Bandingkan di langkah 1.
- `ansible-playbook --syntax-check` tidak bisa kujalankan penuh (Galaxy diblokir di sesi ini). Template dan YAML sudah kucek terpisah.
