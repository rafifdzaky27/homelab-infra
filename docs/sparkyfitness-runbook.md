# Runbook: SparkyFitness di srv-fit-01

VM `srv-fit-01` (192.168.18.27). URL `https://fit.rafifdzaky.com`, hanya internal.
Jalur: iPhone → Tailscale → Caddy (.14) → VM .27 port 3004.

Terraform dijalankan di PowerShell. Ansible dijalankan di WSL. Semua dari clone repo ini.

## Hasil validasi (5 Okt 2026)

Sudah dicek ke sumber:
- Tag Docker Hub: `v1.7.3` adalah rilis terbaru untuk `sparkyfitness_server` dan `sparkyfitness` (diunggah 28 Sep 2026). `latest` menunjuk ke digest yang sama. Seri `v0.x` sudah lama.
- Compose di tag `v1.7.3` (`docker/docker-compose.prod.yml`): nama service, env, port `3004:80`, mount `/var/lib/postgresql`, image `postgres:18.3-alpine`, dan healthcheck DB sudah dicocokkan dengan template kita.
- `.env.example` dan halaman environment variables di docs resmi: nama env dan cara generate secret dicocokkan.
- Aplikasi iOS ada di App Store. Docs resmi menyebut aplikasi mobile butuh HTTPS.
- Template Ansible dirender dengan Ansible asli, `ansible-playbook --syntax-check` lolos untuk `fitness.yml` dan `caddy.yml`. YAML compose hasil render valid.

Belum bisa dicek dari sini (cek sendiri saat deploy):
- Perintah `terraform plan` dan `apply` (Terraform tidak tersedia di sesi ini). File `fitness.tf` hanya beda nama, IP, dan RAM dari `pitwall.tf`.
- Perilaku aturan DOCKER-USER di VM. Karena itu ada tes negatif di langkah 6.
- Login aplikasi iOS ke server kita. Docs resmi tidak merinci langkahnya.
- RAM 2048 MB masih perlu kamu cocokkan dengan tabel RAM playbook.

## 0. Ambil branch
```powershell
git fetch origin
git checkout feat/sparkyfitness-srv-fit-01
```

## 1. Buat VM (Terraform, PowerShell)
```powershell
cd terraform
terraform plan
```
Expected: hanya `proxmox_vm_qemu.fitness` yang ditambah. Tidak ada VM lain berubah.
Kalau ada perubahan lain, berhenti dan kirim outputnya.
```powershell
terraform apply
```
Verify: `ssh devops@192.168.18.27` berhasil.

## 2. Buat secret (WSL)
```bash
cd ansible
cp group_vars/fitness/vault.yml.example group_vars/fitness/vault.yml
openssl rand -hex 32                                   # sparky_api_encryption_key (64 hex)
openssl rand -base64 32                                # sparky_better_auth_secret
openssl rand -base64 36 | tr -d '/+=' | cut -c1-40     # tiap password (3 kali)
nano group_vars/fitness/vault.yml
ansible-vault encrypt group_vars/fitness/vault.yml
```
Isi `sparky_admin_email` dengan email loginmu.
Simpan semua secret ke password manager.
- `BETTER_AUTH_SECRET` tidak boleh berubah setelah 2FA aktif, kalau tidak kamu terkunci.
- API encryption key tidak boleh berubah, kalau tidak data provider eksternal tidak terbaca.
- Password DB hanya dibaca saat database pertama dibuat. Jangan diubah setelahnya.

Repo ini publik. Pastikan `vault.yml` terenkripsi (baris pertama `$ANSIBLE_VAULT`) sebelum `git add`.

## 3. Deploy VM (Ansible)
Repo di `/mnt/c` itu world-writable, jadi Ansible mengabaikan `ansible.cfg`. Set dulu, dan ulangi di tiap terminal WSL baru:
```bash
export ANSIBLE_CONFIG=$PWD/ansible.cfg   # jalankan dari folder ansible
```
```bash
ansible-playbook playbooks/fitness.yml --ask-vault-pass --check --diff
ansible-playbook playbooks/fitness.yml --ask-vault-pass
```
Verify di VM:
```bash
ssh devops@192.168.18.27
docker ps                      # 3 container Up, sparkyfitness-db healthy
sudo iptables -S DOCKER-USER   # ada aturan DROP untuk port 3004
```

## 4. DNS
- AdGuard (.11): `ansible-playbook playbooks/adguard.yml --ask-vault-pass`. Template sudah punya rewrite `fit.rafifdzaky.com` → 192.168.18.14.
- Pi-hole (.12): tambah manual di Local DNS Records: `fit.rafifdzaky.com` → `192.168.18.14`. Harus sama dengan AdGuard.
- Jangan buat record publik di Cloudflare. Jangan buat wildcard `*.rafifdzaky.com` di DNS lokal.

## 5. Caddy
```bash
ansible-playbook playbooks/caddy.yml --ask-vault-pass
```
Verify:
```bash
dig +short fit.rafifdzaky.com @192.168.18.11     # 192.168.18.14
dig +short fit.rafifdzaky.com @192.168.18.12     # 192.168.18.14
curl -I https://fit.rafifdzaky.com               # 200, sertifikat valid
```
Kalau sertifikat gagal terbit, cek `journalctl -u caddy -n 50` di srv-proxy-01. Token Cloudflare harus bisa edit DNS zone `rafifdzaky.com`.

## 6. Tes negatif (wajib)
Dari PC (bukan .14), port 3004 harus ditolak:
```bash
curl -m 5 http://192.168.18.27:3004     # harus timeout
```
Dari srv-proxy-01, harus tembus:
```bash
curl -I http://192.168.18.27:3004       # 200
```
Dari luar jaringan tanpa Tailscale, `https://fit.rafifdzaky.com` tidak boleh bisa dibuka.
Kalau tes pertama tembus, berhenti. Aturan DOCKER-USER tidak bekerja dan port terbuka ke LAN.

## 7. Akun pertama
1. Buka `https://fit.rafifdzaky.com`, daftar dengan email admin yang sama dengan `sparky_admin_email`.
2. Ubah `sparky_disable_signup: true` di `ansible/group_vars/fitness/main.yml`.
3. Jalankan ulang `ansible-playbook playbooks/fitness.yml --ask-vault-pass`.
4. Cek bahwa pendaftaran baru tertutup.

## 8. iPhone
1. Tailscale aktif.
2. Install SparkyFitness dari App Store: https://apps.apple.com/us/app/sparkyfitness/id6757314392
3. Isi server URL `https://fit.rafifdzaky.com`, lalu login.
4. Aktifkan sinkron Apple Health. Beri izin berat badan dan langkah.
Kalau gagal konek, buka laporan diagnostik di bagian bawah halaman pengaturan aplikasi, dan kirim ke aku.

## 9. Data awal
Isi profil dan target 79.9 kg pada 25 Nov 2026. Lalu input berat dari tracker:
19 Sep 89.2, 20 Sep 89.1, 26 Sep 88.3, 27 Sep 87.35, 28 Sep 87.8, 3 Okt 87.95, 4 Okt 87.05, 5 Okt 87.0.
Lingkar perut: 25 Sep 103.5, 27 Sep 97, 5 Okt 100.

## 10. Uji backup
```bash
ssh devops@192.168.18.27
sudo systemctl start sparky-backup.service && journalctl -u sparky-backup -n 20
sudo restic -r /var/backups/sparky-restic --password-file /etc/sparky-backup/restic-password snapshots
sudo systemctl start sparky-restore-test.service && journalctl -u sparky-restore-test -n 20
```
Expected: `backup ok` dan `restore test ok`.
Backup offsite (GDrive) belum aktif. Isi `sparky_backup_offsite_repo` setelah rclone remote siap.

## Upgrade versi
Docs resmi: backup database dan `.env` dulu. Lalu:
1. Jalankan `sudo systemctl start sparky-backup.service`.
2. Cek tag baru di Docker Hub dan baca catatan rilis di GitHub.
3. Ubah `sparky_version` di `ansible/roles/sparky_host/defaults/main.yml`.
4. Jalankan `fitness.yml`.

## Rollback
```bash
ssh devops@192.168.18.27 "cd /opt/sparky && docker compose down"
```
Hapus blok `fit.rafifdzaky.com` dari Caddyfile, lalu jalankan ulang `caddy.yml`.
Hapus VM: hapus `terraform/fitness.tf`, lalu `terraform apply`. Data ikut hilang, jadi simpan backup dulu.

## Catatan
- Rewrite AdGuard lama `*.home.arpa` menjawab `192.168.1.14`, bukan `192.168.18.14`. Mungkin typo atau subnet lama. Tidak diubah di PR ini.
- Jangan `apt upgrade` paket caddy di srv-proxy-01 kalau binary-nya hasil build kustom dengan plugin Cloudflare.
- Header IP asli dan jumlah proxy (`SPARKY_FITNESS_TRUSTED_PROXY_HOPS`) tidak diatur. Untuk satu pengguna di jaringan privat ini tidak berpengaruh.
