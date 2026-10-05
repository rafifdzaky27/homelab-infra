# Runbook: Caddy di srv-proxy-01

Host `srv-proxy-01` (192.168.18.14). Ansible dijalankan dari WSL.
Runbook ini mendokumentasikan konfigurasi dan insiden yang sudah diperbaiki. Daftar site bukan bukti semua backend sedang sehat.

## Site dalam template

Source: `ansible/roles/caddy/templates/Caddyfile.j2`.

| Site | Backend / fungsi |
|---|---|
| `jellyfin-private.home.arpa` | 192.168.18.13:8096 |
| `jellyfin-shared.home.arpa` | 192.168.18.26:8096 |
| `cloud.home.arpa` | 192.168.18.19:8090 |
| `ha.home.arpa` | 192.168.18.15:8123 |
| `grafana.home.arpa` | 192.168.18.16:3000 |
| `git.home.arpa` | 192.168.18.17:3000 |
| `http://metrics.home.arpa` | Endpoint metrics |
| `test.home.arpa`, `test.rafifdzaky.com` | Backend verifikasi P04 di 127.0.0.1:5000 |
| `fit.rafifdzaky.com` | SparkyFitness di 192.168.18.27:3004; internal, tanpa public A record atau Tunnel |
| `rafifdzaky.com`, `www.rafifdzaky.com` | Portfolio pada listener lokal port 8081; file statis `/srv/www/portfolio/current`; www redirect ke domain utama |

Jalur portfolio: Cloudflare → Cloudflare Tunnel → cloudflared pada srv-proxy-01 → Caddy `127.0.0.1:8081` → `/srv/www/portfolio/current`.

## Ownership dan aturan perubahan

`/etc/caddy/Caddyfile` sepenuhnya dimiliki Ansible. Jangan edit file server dengan tangan. Ubah `Caddyfile.j2`, review diff, lalu jalankan `playbooks/caddy.yml`. Satu render mengganti seluruh Caddyfile, bukan hanya site yang sedang ditambahkan.

Portfolio memakai literal `root /srv/www/portfolio/current` dalam template. Jangan menggantinya dengan `{$SITE_ROOT}`: `caddy.env` juga dikelola Ansible dan hanya berisi `CF_API_TOKEN`, bukan `SITE_ROOT`.

## 1. Preflight dan review diff (WSL)

```bash
cd /mnt/c/Users/Rafif/Downloads/homelab-infra/ansible
export ANSIBLE_CONFIG=$PWD/ansible.cfg
ansible-playbook playbooks/caddy.yml --ask-vault-pass --check --diff
```

Expected: hanya perubahan yang direncanakan. **STOP jika diff menghapus atau mengubah baris apa pun yang tidak kamu maksudkan**, termasuk site portfolio port 8081. Jangan lanjut ke apply untuk menambahkan satu site jika site lain hilang. Check mode sendiri tidak menerapkan perubahan.

## 2. Terapkan setelah diff aman (WSL)

```bash
ansible-playbook playbooks/caddy.yml --ask-vault-pass
```

Expected: tidak ada failed/unreachable. Recap saja tidak membuktikan site sehat; lanjutkan validate dan pemeriksaan HTTP. Rerun source yang sama tidak boleh menghilangkan site lain.

## 3. Validate dengan environment service (SSH ke srv-proxy-01)

```bash
sudo bash -c "set -a; . /etc/caddy/caddy.env; caddy validate --config /etc/caddy/Caddyfile"
```

Expected: konfigurasi valid. `sudo caddy validate` tanpa environment gagal karena `CF_API_TOKEN` hanya berasal dari systemd EnvironmentFile. Jangan cetak `caddy.env` atau jalankan dengan tracing (`set -x`). Jika validasi gagal, STOP dan review template/environment; jangan menambal Caddyfile live.

## 4. Pemeriksaan setelah perubahan

Pada srv-proxy-01, setelah SSH:

```bash
curl -sI -H "Host: rafifdzaky.com" http://127.0.0.1:8081/
```

Dari luar homelab/tailnet:

```bash
curl -sI https://rafifdzaky.com
curl -sI https://www.rafifdzaky.com
```

Expected: origin dan domain utama 200; www redirect ke `https://rafifdzaky.com`. Periksa juga site yang sengaja diubah, misalnya SparkyFitness. Jika origin connection refused atau domain utama 502, STOP: periksa listener/blok portfolio sebelum mengubah Tunnel atau DNS.

Rollback: pulihkan perubahan yang bermasalah pada template repo, ulangi check/diff, lalu terapkan dan ulangi pemeriksaan. Jangan rollback dengan edit manual pada server.

## Insiden 2026-10-05

- 2026-09-26: blok portfolio port 8081 ditambah manual ke `/etc/caddy/Caddyfile`, tetapi tidak ke template Ansible.
- 2026-10-05 03:05: `caddy.yml` diterapkan untuk SparkyFitness. Render template menghapus blok portfolio.
- cloudflared mencatat `dial tcp 127.0.0.1:8081: connect: connection refused`. Cloudflare memberi 502 untuk domain utama dan www.
- Fix sudah diterapkan dan di-commit: blok portfolio ditambah ke template dengan root literal; `caddy.yml` dijalankan ulang. Site kembali 200 menurut laporan pemilik.
- Pencegahan: template adalah source of truth; review seluruh diff, validate dengan environment service, lalu cek origin dan akses publik setelah setiap perubahan Caddy.

Monitor eksternal sudah dipasang pemilik, seperti pola Pit Wall M5-6: UptimeRobot HTTP(s)-Keyword pada `https://rafifdzaky.com/`, keyword `Rafif Dzaky Daniswara` wajib ada, interval 5 menit, alert email dan mobile push. Tidak ada akun/dashboard yang dibuat atau diubah dalam pekerjaan dokumentasi ini. Check GitHub `status.yml` mengisi `/status`, bukan mengirim alert.
