# qBittorrent with WireGuard VPN

A leak-proof qBittorrent container that routes all traffic through WireGuard VPN while allowing local network access to the WebUI.

[![Docker Image](https://img.shields.io/docker/v/serversathome/qbittorrent-vpn?sort=semver)](https://hub.docker.com/r/serversathome/qbittorrent-vpn)
[![Docker Pulls](https://img.shields.io/docker/pulls/serversathome/qbittorrent-vpn)](https://hub.docker.com/r/serversathome/qbittorrent-vpn)
[![Build Status](https://github.com/serversathome/qbittorrent-vpn/workflows/Build%20and%20Push%20Docker%20Image/badge.svg)](https://github.com/serversathome/qbittorrent-vpn/actions)

## Features

- ✅ **Leak-proof VPN**: All qBittorrent traffic forced through WireGuard
- ✅ **Local Network Access**: WebUI accessible from local networks without VPN
- ✅ **Port Forwarding**: Support for VPN provider port forwarding
- ✅ **Auto-updates**: Automatically rebuilds when LinuxServer.io updates their base image
- ✅ **Multi-arch**: Supports AMD64 and ARM64
- ✅ **Health Monitoring**: Built-in VPN connection monitoring
- ✅ **Based on LinuxServer.io**: Uses the trusted linuxserver/qbittorrent base

## Quick Start

### 1. Prepare Your WireGuard Config

Create a directory structure:

```bash
mkdir -p config/wireguard
mkdir -p downloads
```

Place your WireGuard configuration file at `config/wireguard/wg0.conf`

Example `wg0.conf`:
```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.2.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
Endpoint = vpn.example.com:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

### 2. Run with Docker Compose

Create a `docker-compose.yml`:

```yaml
version: "3.8"

services:
  qbittorrent-vpn:
    image: serversathome/qbittorrent-vpn:latest
    container_name: qbittorrent-vpn
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=1
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - WEBUI_PORT=8080
      - VPN_PORT=12345  # Optional: Your forwarded port from VPN provider
    volumes:
      - ./config:/config
      - ./downloads:/downloads
    ports:
      - 8080:8080
    restart: unless-stopped
```

### 3. Start the Container

```bash
docker-compose up -d
```

### 4. Access qBittorrent

Open your browser to `http://YOUR_SERVER_IP:8080`

Default credentials:
- Username: `admin`
- Password: `adminadmin` (change this immediately!)

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PUID` | User ID for file permissions | `1000` |
| `PGID` | Group ID for file permissions | `1000` |
| `TZ` | Timezone | `Etc/UTC` |
| `WEBUI_PORT` | qBittorrent WebUI port | `8080` |
| `VPN_PORT` | Port forwarded by your VPN provider (optional) | - |
| `DEBUG` | Enable iptables logging for troubleshooting | `false` |

### Local Networks (Bypass VPN)

The following networks automatically bypass the VPN for local access:
- `10.0.0.0/8`
- `192.168.0.0/16`
- `172.16.0.0/12`
- `100.64.0.0/10`
- `100.84.0.0/12`

### Port Forwarding

If your VPN provider supports port forwarding:

1. Get your forwarded port from your VPN provider
2. Set the `VPN_PORT` environment variable to this port
3. The container will automatically configure qBittorrent to use this port

## Verification

### Check VPN is Working

```bash
# Check WireGuard status
docker exec qbittorrent-vpn wg show

# Check external IP (should be your VPN IP)
docker exec qbittorrent-vpn curl --interface wg0 https://api.ipify.org
```

### Check Leak Protection

```bash
# This should fail (timeout) - proving traffic can't leak
docker exec qbittorrent-vpn curl --interface eth0 https://api.ipify.org

# Check iptables rules
docker exec qbittorrent-vpn iptables -L -v -n
```

## Troubleshooting

### WireGuard Not Starting

**Error**: `Failed to load WireGuard kernel module`

**Solution**: Install WireGuard on your Docker host:

```bash
# Ubuntu/Debian
sudo apt-get install wireguard

# If kernel module isn't available, install DKMS version
sudo apt-get install wireguard-dkms
```

### Can't Access WebUI

1. Ensure your Docker host's firewall allows port 8080
2. Check the container is running: `docker ps`
3. Check logs: `docker logs qbittorrent-vpn`

### VPN Connection Issues

Enable debug mode:

```yaml
environment:
  - DEBUG=true
```

Then check logs for dropped packets:

```bash
docker logs -f qbittorrent-vpn
```

## VPN Provider Guides

### Mullvad

1. Download WireGuard config from [Mullvad](https://mullvad.net/en/account/#/wireguard-config/)
2. Save as `config/wireguard/wg0.conf`
3. Port forwarding: Check [Mullvad's port forwarding guide](https://mullvad.net/en/help/port-forwarding-and-mullvad/)

### ProtonVPN

1. Download WireGuard config from ProtonVPN dashboard
2. Save as `config/wireguard/wg0.conf`
3. Note: ProtonVPN may not support port forwarding on all servers

### Custom VPN Provider

Any VPN provider that offers WireGuard configs will work. Just save the config as `wg0.conf`.

## Security Features

### Kill Switch

The container implements a strict kill switch:
- Default policy: **DROP** all traffic
- Only allows traffic through WireGuard interface
- Local network access for WebUI only
- No DNS leaks (DNS requests go through VPN)

### Network Isolation

All qBittorrent traffic is isolated and forced through the VPN tunnel. The container will not start if the VPN connection fails.

## Building Locally

If you want to build the image yourself:

```bash
git clone https://github.com/serversathome/qbittorrent-vpn.git
cd qbittorrent-vpn
docker build -t qbittorrent-vpn:local .
```

## Auto-Updates

This image automatically rebuilds daily to stay in sync with the LinuxServer.io base image. GitHub Actions checks for updates and rebuilds when necessary.

## Support

- **Issues**: [GitHub Issues](https://github.com/serversathome/qbittorrent-vpn/issues)
- **Base Image**: [LinuxServer.io qBittorrent](https://github.com/linuxserver/docker-qbittorrent)

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Based on [LinuxServer.io's qBittorrent image](https://github.com/linuxserver/docker-qbittorrent)
- Inspired by the need for secure torrenting

---

**⚠️ Disclaimer**: This container is for educational purposes. Ensure you comply with your local laws and your VPN provider's terms of service.
