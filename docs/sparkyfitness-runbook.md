# Runbook: SparkyFitness di srv-fit-01

VM `srv-fit-01` (192.168.18.27). URL `https://fit.rafifdzaky.com`, hanya internal.
Jalur: iPhone → Tailscale → Caddy (.14) → VM .27 port 3004.
Terraform di PowerShell. Ansible di WSL. Ikuti urutan, jangan lompat langkah.

## Yang sudah diuji sebelum runbook ini ditulis

Diuji nyata di Ubuntu 24.04 dengan Docker:
- Stack `v1.7.3` dari template kita: 3 container healthy, `/api/health` UP, halaman web 200.
- Daftar akun lewat origin `https://fit.rafifdzaky.com`: berhasil, akun dengan `sparky_admin_email` otomatis admin. Origin lain ditolak (403).
- Login tanpa header Origin (cara aplikasi mobile): berhasil.
- `SPARKY_FITNESS_DISABLE_SIGNUP=true`: pendaftaran baru ditolak.
- Backup dan restore test: `backup ok`, restore 109 dari 109 tabel, `restore test ok`. Snapshot memakai path tetap sehingga retensi bekerja.
- Aturan DOCKER-USER: sumber yang diizinkan dapat 200, sumber lain timeout. Aturan tidak dobel saat dijalankan dua kali dan tetap ada setelah Docker restart.
- Modul `docker_compose_v2` jalan dan idempotent. `ansible-playbook --syntax-check` lolos.
- Caddyfile lengkap lolos `caddy validate` dengan modul Cloudflare.
- Tag `v1.7.3` adalah rilis terbaru di Docker Hub (28 Sep 2026). Compose cocok dengan compose upstream di tag itu.

Tidak bisa diuji dari luar homelab (ada cek di langkah terkait):
- Caddyfile live di srv-proxy-01 sama dengan template repo (langkah 6).
- Record DNS dan sertifikat publik (langkah 6 dan 7).
- Aplikasi iOS ke servermu (langkah 9).

## 0. Persiapan terminal WSL (tiap buka terminal baru)
```bash
cd /mnt/c/Users/Rafif/Downloads/homelab-infra
git fetch origin && git checkout feat/sparkyfitness-srv-fit-01 && git pull
cd ansible
export ANSIBLE_CONFIG=$PWD/ansible.cfg
ansible-galaxy collection list 2>/dev/null | grep -E "community\.(docker|general)"
```
Kenapa `ANSIBLE_CONFIG`: folder di `/mnt/c` world-writable, jadi Ansible mengabaikan `ansible.cfg` (inventory dan roles hilang).
Expected: dua collection muncul. Kalau tidak: `ansible-galaxy collection install -r requirements.yml`.

## 1. Buat VM (Terraform, PowerShell)
```powershell
cd C:\Users\Rafif\Downloads\homelab-infra\terraform
terraform plan
```
Expected: hanya `proxmox_vm_qemu.fitness` yang ditambah. Kalau ada perubahan lain, berhenti.
```powershell
terraform apply
```

## 2. SSH pertama ke VM (WSL, wajib sebelum Ansible)
```bash
ssh -i ~/.ssh/id_ed25519_homelab devops@192.168.18.27 'cloud-init status --wait; hostname'
```
- Ketik `yes` saat ditanya host key. Ansible tidak bisa menjawab prompt ini sendiri.
- `cloud-init status --wait` menunggu cloud-init selesai, supaya apt tidak terkunci saat Ansible jalan.
- Expected: `status: done` lalu `srv-fit-01`.
- Kalau muncul "REMOTE HOST IDENTIFICATION HAS CHANGED": `ssh-keygen -R 192.168.18.27`, lalu ulangi.

## 3. Buat secret (WSL)
```bash
cp group_vars/fitness/vault.yml.example group_vars/fitness/vault.yml
openssl rand -hex 32                                   # sparky_api_encryption_key
openssl rand -base64 32                                # sparky_better_auth_secret
openssl rand -base64 36 | tr -d '/+=' | cut -c1-40     # sparky_db_password, sparky_app_db_password, sparky_restic_password
nano group_vars/fitness/vault.yml                      # isi juga sparky_admin_email
ansible-vault encrypt group_vars/fitness/vault.yml
head -1 group_vars/fitness/vault.yml                   # harus $ANSIBLE_VAULT;1.1;AES256
```
- Pakai password vault yang SAMA dengan `group_vars/all/vault.yml`. `--ask-vault-pass` hanya menerima satu password.
- Simpan semua secret di password manager.
- `BETTER_AUTH_SECRET`, API key, dan password DB tidak boleh berubah setelah deploy pertama.
- Repo ini publik. Jangan `git add` vault yang belum terenkripsi.

## 4. Deploy pertama (tanpa --check)
```bash
ansible-playbook playbooks/fitness.yml --ask-vault-pass
```
Jangan pakai `--check` di VM baru. Mode check tidak benar-benar menjalankan `apt update`, jadi paket seperti `fail2ban` terlihat "tidak ada", dan Docker belum terpasang untuk task berikutnya. Ini yang tadi gagal. VM masih kosong, jadi run langsung aman.
Expected: `failed=0`. Pull image pertama butuh beberapa menit.

Verify:
```bash
ssh -i ~/.ssh/id_ed25519_homelab devops@192.168.18.27 \
  'docker ps --format "{{.Names}} {{.Status}}"; sudo iptables -S DOCKER-USER; systemctl list-timers "sparky*" --no-pager; curl -s http://192.168.18.27:3004/api/health'
```
Expected: 3 container `healthy`, satu baris `DROP` dengan `! -s 192.168.18.14/32 ... 3004`, dua timer sparky, dan `{"status":"UP"}`.

## 5. Tes firewall (wajib, sebelum Caddy dan DNS)
Dari WSL (bukan .14), harus timeout:
```bash
curl -m 5 http://192.168.18.27:3004 ; echo "exit=$?"     # expected exit=28
```
Dari srv-proxy-01, harus 200:
```bash
ssh -i ~/.ssh/id_ed25519_homelab devops@192.168.18.14 'curl -s -o /dev/null -w "%{http_code}\n" http://192.168.18.27:3004/'
```
Kalau tes pertama dapat 200, berhenti. Port terbuka ke LAN.

## 6. Caddy
Cek dulu bedanya dengan Caddyfile live:
```bash
ansible-playbook playbooks/caddy.yml --ask-vault-pass --check --diff
```
Expected: diff Caddyfile hanya menambah blok `fit.rafifdzaky.com`. Kalau ada baris lain yang berubah atau terhapus, berhenti dan kirim diff-nya. Artinya Caddyfile live beda dengan repo.
Kalau aman:
```bash
ansible-playbook playbooks/caddy.yml --ask-vault-pass
curl -sI --resolve fit.rafifdzaky.com:443:192.168.18.14 https://fit.rafifdzaky.com | head -1
```
Expected: `HTTP/2 200` tanpa `-k`. Ini membuktikan sertifikat publik dan Caddy sebelum DNS lokal dipasang (pola P04 Step 9).
Kalau gagal: `ssh devops@192.168.18.14 'journalctl -u caddy -n 50 --no-pager'`.

## 7. DNS lokal (manual di UI, kedua resolver)
Jangan jalankan `adguard.yml`. Template AdGuard di repo menimpa seluruh config live dan masih menjawab `*.home.arpa` ke `192.168.1.14`. Menjalankannya bisa mematikan semua nama `home.arpa`.
- AdGuard `http://192.168.18.11:3000` → Filters → DNS rewrites → Add: `fit.rafifdzaky.com` → `192.168.18.14`.
- Pi-hole `http://192.168.18.12/admin` → Settings → Local DNS Records → `fit.rafifdzaky.com` → `192.168.18.14`.
- Jangan buat record publik di Cloudflare. Jangan buat wildcard `*.rafifdzaky.com`.
Verify:
```bash
dig +short @192.168.18.11 fit.rafifdzaky.com     # 192.168.18.14
dig +short @192.168.18.12 fit.rafifdzaky.com     # 192.168.18.14
dig +short @1.1.1.1 fit.rafifdzaky.com           # kosong
curl -sI https://fit.rafifdzaky.com | head -1     # HTTP/2 200
```

## 8. Akun pertama dan tutup pendaftaran
1. Buka `https://fit.rafifdzaky.com`. Daftar dengan email yang sama dengan `sparky_admin_email`. Akun ini otomatis admin.
2. Ubah `sparky_disable_signup: true` di `group_vars/fitness/main.yml`.
3. Jalankan:
```bash
ansible-playbook playbooks/fitness.yml --ask-vault-pass --check --diff   # sekarang --check aman
ansible-playbook playbooks/fitness.yml --ask-vault-pass
```
4. Coba daftar akun lain. Expected: "Signups are currently disabled by the administrator."
5. Commit perubahan `main.yml` dan `vault.yml` (terenkripsi), lalu push.

## 9. iPhone
1. Tailscale aktif. Playbook mengatur DNS Tailscale ke .11 dan .12 dengan Override DNS, jadi nama ini ter-resolve lewat Tailscale.
2. Install SparkyFitness dari App Store: https://apps.apple.com/us/app/sparkyfitness/id6757314392
3. Server URL `https://fit.rafifdzaky.com`, lalu login.
4. Aktifkan Apple Health. Izinkan berat badan dan langkah.
5. Matikan Wi-Fi rumah, pakai data seluler + Tailscale, buka app lagi. Harus tetap jalan.
Kalau gagal, buka laporan diagnostik di bawah halaman Settings aplikasi dan kirim ke aku.

## 10. Data awal
Profil dan target 79.9 kg pada 25 Nov 2026. Berat dari tracker:
19 Sep 89.2, 20 Sep 89.1, 26 Sep 88.3, 27 Sep 87.35, 28 Sep 87.8, 3 Okt 87.95, 4 Okt 87.05, 5 Okt 87.0.
Lingkar perut: 25 Sep 103.5, 27 Sep 97, 5 Okt 100.

## 11. Uji backup
```bash
ssh -i ~/.ssh/id_ed25519_homelab devops@192.168.18.27
sudo systemctl start sparky-backup.service; journalctl -u sparky-backup -n 5 --no-pager
sudo systemctl start sparky-restore-test.service; journalctl -u sparky-restore-test -n 5 --no-pager
```
Expected: `backup ok`, lalu `tables live=N restored=N` dan `restore test ok`.
Backup masih lokal di disk VM. Backup ke GDrive (`sparky_backup_offsite_repo`) menyusul setelah rclone remote siap.

## Upgrade versi
1. `sudo systemctl start sparky-backup.service` di VM.
2. Cek tag baru di Docker Hub dan catatan rilis di GitHub SparkyFitness.
3. Ubah `sparky_version` di `roles/sparky_host/defaults/main.yml`, lalu jalankan `fitness.yml`.

## Rollback
```bash
ssh devops@192.168.18.27 'cd /opt/sparky && docker compose down'
```
Hapus blok `fit.rafifdzaky.com` dari Caddyfile, jalankan `caddy.yml`, lalu hapus record DNS di AdGuard dan Pi-hole.
Hapus VM: hapus `terraform/fitness.tf`, lalu `terraform apply`. Data ikut hilang, simpan backup dulu.
Unit firewall sengaja tidak menghapus aturannya saat di-stop. Hapus manual kalau perlu:
`sudo iptables -D DOCKER-USER ! -s 192.168.18.14 -p tcp -m conntrack --ctorigdstport 3004 --ctdir ORIGINAL -j DROP`
