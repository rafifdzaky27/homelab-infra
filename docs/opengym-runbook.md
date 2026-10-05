# Runbook: openGym di srv-gym-01

VM `srv-gym-01` (192.168.18.28). URL `https://gym.rafifdzaky.com`, **publik**, tanpa Tailscale.
Jalur: iPhone (Safari PWA) → Cloudflare → tunnel `opengym` → container `cloudflared` → `web:80` (nginx) → `api:3000`.
Tidak ada port yang dibuka ke LAN. Tidak lewat Caddy di srv-proxy-01.
Terraform di PowerShell. Ansible di WSL. Ikuti urutan, jangan lompat langkah.

## Yang sudah diuji sebelum runbook ini ditulis

- Compose hasil render template lolos `docker compose config`.
- Stack `1.3.9` (api, web, media) jalan di Docker lokal: `media` selesai dan berhenti, `/api/health` lewat nginx membalas `{"ok":true,...}`, halaman web 200, `data/secret` dan `data/vapid.json` dibuat.
- `docker compose up --wait` **tidak** dipakai: healthcheck image jalan tiap 5 menit, jadi `--wait` tertahan di "starting". Role memakai polling `/api/health`.
- `backup.sh` dan `restore-test.sh` di Ubuntu 24.04: `backup ok`, `restore test ok`. Uji negatif (jumlah user beda) gagal sesuai harapan.
- Tag `1.3.9` (rilis terbaru) ada di GHCR untuk `opengym-api` dan `opengym-web`.

Tidak bisa diuji dari luar homelab: tunnel, passkey di iPhone, dan playbook di VM sungguhan (ada cek di langkah terkait).

## Keamanan, karena ini publik
- Login hanya passkey (Face ID). `PASSWORD_LOGIN` mati, jadi tidak ada password yang bisa ditebak.
- `ALLOW_GUEST=0`: tidak ada mode tamu.
- Setelah profilmu jadi: `INVITE_ONLY=1` dan `ADMIN_UIDS` diisi (langkah 8). Sebelum itu, pendaftaran terbuka. Kerjakan langkah 6 sampai 8 berturut-turut.
- AI coach dimatikan paksa (`COACH_DISABLED=1`).
- `RP_ID` dan `ORIGIN` terikat ke `gym.rafifdzaky.com`. Mengganti domain nanti = semua passkey harus daftar ulang.

## 0. Persiapan terminal WSL (tiap buka terminal baru)
```bash
cd /mnt/c/Users/Rafif/Downloads/homelab-infra
git fetch origin && git checkout feat/opengym-srv-gym-01 && git pull
cd ansible
export ANSIBLE_CONFIG=$PWD/ansible.cfg
```
Kenapa `ANSIBLE_CONFIG`: folder di `/mnt/c` world-writable, jadi Ansible mengabaikan `ansible.cfg`.

## 1. Buat VM (Terraform, PowerShell)
Pastikan `192.168.18.28` di luar range DHCP router. Waktu runbook ditulis, IP ini tidak membalas ping.
```powershell
cd C:\Users\Rafif\Downloads\homelab-infra\terraform
terraform plan
```
Expected: hanya `proxmox_vm_qemu.opengym` yang ditambah. Kalau ada perubahan lain, berhenti.
```powershell
terraform apply
```

## 2. SSH pertama ke VM (WSL, wajib sebelum Ansible)
```bash
ssh -i ~/.ssh/id_ed25519_homelab devops@192.168.18.28 'cloud-init status --wait; hostname'
```
- Ketik `yes` saat ditanya host key.
- Expected: `status: done` lalu `srv-gym-01`.
- Kalau muncul "REMOTE HOST IDENTIFICATION HAS CHANGED": `ssh-keygen -R 192.168.18.28`, lalu ulangi.

## 3. Tunnel Cloudflare (browser)
1. Cloudflare Zero Trust → Networks → Tunnels → **Create a tunnel** → Cloudflared. Nama: `opengym`.
2. Di layar install, pilih Docker. Salin **token** saja (teks panjang setelah `--token`, diawali `eyJ`). Jangan jalankan perintahnya.
3. Tab **Public Hostname** → Add:
   - Subdomain `gym`, domain `rafifdzaky.com`
   - Service type `HTTP`, URL `web:80`
4. Save. Cloudflare membuat record DNS `gym` sendiri.

Tunnel terpisah dari Pitwall dan portfolio, jadi masalah di satu tunnel tidak menjatuhkan yang lain.
Jangan buat wildcard `*.rafifdzaky.com`.

## 4. Buat secret (WSL)
```bash
cp group_vars/gym/vault.yml.example group_vars/gym/vault.yml
openssl rand -base64 36 | tr -d '/+=' | cut -c1-40     # opengym_restic_password
nano group_vars/gym/vault.yml                          # isi token tunnel dari langkah 3
ansible-vault encrypt group_vars/gym/vault.yml
head -1 group_vars/gym/vault.yml                       # harus $ANSIBLE_VAULT;1.1;AES256
```
- Pakai password vault yang SAMA dengan `group_vars/all/vault.yml`.
- Simpan restic password di password manager. Tanpa itu backup tidak bisa dibuka.
- Repo ini publik. Jangan `git add` vault yang belum terenkripsi.

## 5. Deploy pertama (tanpa --check)
```bash
ansible-playbook playbooks/opengym.yml --ask-vault-pass
```
Jangan pakai `--check` di VM baru (alasannya sama dengan runbook SparkyFitness langkah 4).
Run pertama mengunduh media latihan sekitar 140 MB, jadi task "Start the stack" bisa makan beberapa menit.
Expected: `failed=0`, dan task "Wait until web answers /api/health" ok.

Verify:
```bash
ssh -i ~/.ssh/id_ed25519_homelab devops@192.168.18.28 \
  'cd /opt/opengym && docker compose ps -a --format "{{.Service}} {{.Status}}"; docker compose logs --tail 5 cloudflared; systemctl list-timers "opengym*" --no-pager'
```
Expected: `api` dan `web` Up, `media` Exited (0), `cloudflared` Up dengan log `Registered tunnel connection` (4 baris), dan dua timer opengym.

Tidak ada port terbuka ke LAN. Harus gagal (connection refused):
```bash
curl -m 5 http://192.168.18.28 ; curl -m 5 http://192.168.18.28:8080 ; echo "exit=$?"
```

Dari luar:
```bash
curl -s https://gym.rafifdzaky.com/api/health
```
Expected: `{"ok":true,"users":0}`.

## 6. Profil pertama (iPhone, langsung setelah langkah 5)
1. Buka Safari → `https://gym.rafifdzaky.com`.
2. **Create profile**, beri nama, simpan passkey dengan Face ID.
3. Share → **Add to Home Screen**. Buka app dari ikon Home Screen.
4. Settings → Notifications kalau mau pengingat latihan (Web Push hanya jalan dari app Home Screen).

## 7. Cari user id kamu
```bash
ssh -i ~/.ssh/id_ed25519_homelab devops@192.168.18.28 \
  'sudo python3 -c "import json;[print(u[\"id\"],u.get(\"name\")) for u in json.load(open(\"/opt/opengym/data/db.json\"))[\"users\"]]"'
```
Expected: **satu** baris, nama profilmu. Kalau ada lebih dari satu, ada orang lain yang mendaftar. Berhenti dan kirim output-nya.

## 8. Kunci pendaftaran
Di `group_vars/gym/main.yml`:
```yaml
opengym_admin_uids: "<id dari langkah 7>"
opengym_invite_only: true
```
```bash
ansible-playbook playbooks/opengym.yml --ask-vault-pass --check --diff   # sekarang --check aman
ansible-playbook playbooks/opengym.yml --ask-vault-pass
```
Expected diff: hanya `ADMIN_UIDS` dan `INVITE_ONLY` di `api.env`.
Verify: buka situsnya di private tab, coba Create profile. Harus minta invite code. Di app kamu, Settings sekarang punya **Admin dashboard**.
Commit `main.yml` dan `vault.yml` (terenkripsi), lalu push.

## 9. Monitor UptimeRobot (browser)
- Tipe **HTTP(s) - Keyword**, URL `https://gym.rafifdzaky.com/api/health`, keyword `"ok":true` (must exist), interval 5 menit.
- Alert ke email dan push app, sama seperti Pitwall dan portfolio. Kirim test notification.

## 10. Uji backup
```bash
ssh -i ~/.ssh/id_ed25519_homelab devops@192.168.18.28
sudo systemctl start opengym-backup.service; journalctl -u opengym-backup -n 5 --no-pager
sudo systemctl start opengym-restore-test.service; journalctl -u opengym-restore-test -n 5 --no-pager
```
Expected: `backup ok`, lalu `users live=1 restored=1 ...` dan `restore test ok`.
Backup gagal sebelum langkah 6, karena `db.json` baru dibuat setelah profil pertama. Itu normal.
Backup masih lokal di disk VM. Offsite ke GDrive (`opengym_backup_offsite_repo`) menyusul setelah rclone remote siap.

## Upgrade versi
1. `sudo systemctl start opengym-backup.service` di VM.
2. Baca CHANGELOG di GitHub openGym. **1.4.0 (rencana Jan 2027) pindah ke database dan tidak kompatibel.** Jangan naik ke 1.4.x tanpa membaca catatan migrasinya.
3. Pastikan tag baru ada di GHCR, ubah `opengym_version` di `roles/opengym_host/defaults/main.yml`, lalu jalankan `opengym.yml`.

## Rollback
```bash
ssh -i ~/.ssh/id_ed25519_homelab devops@192.168.18.28 'cd /opt/opengym && docker compose down'
```
Hapus public hostname dan tunnel `opengym` di Cloudflare. Record DNS `gym` ikut dihapus.
Hapus VM: hapus `terraform/opengym.tf`, lalu `terraform apply`. Data ikut hilang, simpan backup dulu.
