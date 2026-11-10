# GudDesk

Self-hosted remote desktop Gutekno berbasis [RustDesk](https://github.com/rustdesk/rustdesk) + [rustdesk-server](https://github.com/rustdesk/rustdesk-server).

- Halaman setup: https://guddesk.gutekno.com
- ID / Relay server: `id.guddesk.gutekno.com` (Cloudflare DNS-only → `148.230.101.168`)
- Key: lihat halaman setup atau `/opt/gutekno/guddesk/data/id_ed25519.pub` di server

## Komponen

| Service | Fungsi | Port |
|---|---|---|
| `guddesk-hbbs` | ID / rendezvous server | 21115/tcp, 21116/tcp+udp, 21118/tcp |
| `guddesk-hbbr` | Relay server | 21117/tcp, 21119/tcp |
| `guddesk-web` | Halaman setup (via Traefik) | 80/443 |

`hbbs` dan `hbbr` pakai `network_mode: host` supaya IP asli client terlihat (dibutuhkan untuk hole punching P2P).
Port RustDesk tidak bisa lewat proxy Cloudflare, jadi `id.guddesk.gutekno.com` harus tetap DNS-only (awan abu-abu).
`guddesk.gutekno.com` (halaman setup) boleh proxied.

Firewall Hostinger (`gutekno-srv1028008`) sudah dibuka untuk TCP 21115-21119 dan UDP 21116.

## Deploy

Semua build di local PC (tidak ada build di server maupun GitHub Actions):

```bash
make build-client          # .deb + .apk dari ../guddesk-client ke ./downloads (Docker)
make remote-deploy-prod    # rsync config + downloads, docker compose pull/up di server
make release-prod          # keduanya
```

Build pertama lama (vcpkg/ffmpeg, Rust, Flutter); berikutnya pakai cache di Docker volume `guddesk-*`.
APK ditandatangani dengan key di `~/.config/guddesk/android/debug.keystore`. Backup file itu:
kalau hilang, update APK di HP yang sudah install akan ditolak (harus uninstall dulu).
macOS tidak di-build karena butuh Mac.

Keypair dibuat otomatis oleh `hbbs` saat pertama jalan di `data/`. Jangan hapus `data/id_ed25519*`,
kalau hilang semua client harus diisi key baru.
