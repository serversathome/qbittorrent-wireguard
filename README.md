# qBittorrent + WireGuard (Killswitch Edition)

A custom Docker image based on **linuxserver/qbittorrent** with:
- Integrated **WireGuard VPN**
- A strict **killswitch**
- **Local network bypass** for LAN WebUI
- **Optional VPN port forwarding**
- **Self-healing watchdog**
- **Automated rebuilds** when linuxserver.io updates

---

## 🚀 Quick Start

```bash
git clone https://github.com/serversathome/qbittorrent-wireguard.git
cd qbittorrent-wireguard
cp wg0.conf.example config/wg0.conf
# edit wg0.conf with your VPN credentials
docker compose up -d
