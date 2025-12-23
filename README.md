> [!WARNING]
> ⚠️ **Beta Release**
> This project is in **beta**! Features may change, and bugs are likely. Use with caution and report issues in the issue tracker.


# qBittorrent with WireGuard VPN & Killswitch

A Docker container that runs qBittorrent with a built-in WireGuard VPN connection and killswitch. All torrent traffic is routed through the VPN, and if the VPN connection drops, qBittorrent is automatically shut down to prevent any leaks.

## Features

- ✅ **Built-in WireGuard VPN** - No separate VPN container needed
- ✅ **Automatic Killswitch** - Stops all traffic if VPN disconnects
- ✅ **Port Forwarding Support** - Configure forwarded ports from your VPN provider
- ✅ **Local Network Access** - WebUI accessible from your local network
- ✅ **VPN Bypass for LAN** - Local network traffic doesn't go through VPN
- ✅ **Tailscale & Netbird Support** - Access from mesh VPN networks
- ✅ **Health Monitoring** - Automatic VPN connectivity checks
- ✅ **Easy Configuration** - Just drop in your WireGuard config file

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- A WireGuard VPN configuration file from your VPN provider (e.g., AirVPN, Mullvad, ProtonVPN, etc.)

> **💡 Need a VPN?** I personally use and recommend [AirVPN](https://airvpn.org/?referred_by=669318) - they offer native WireGuard support, port forwarding, and excellent privacy. Using this referral link supports the project!

### Step 1: Get Your WireGuard Config

Download a WireGuard configuration file from your VPN provider. It should look something like this:
```ini
[Interface]
Address = 10.x.x.x/32
PrivateKey = your-private-key-here
DNS = 10.128.0.1

[Peer]
PublicKey = server-public-key
Endpoint = vpn.server.com:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 15
```

### Step 2: Create Directory Structure
Create a `configs/qbittorrent` dataset for your files to be persistent in. 

### Step 3: Place Your WireGuard Config

Copy your WireGuard config file to `wg0.conf` inside the `configs/qbittorrent` dataset you just created.

### Step 4: Create docker-compose.yml

Create a `docker-compose.yml` file:
```yaml
services:
  qbittorrent-wireguard:
    image: serversathome/qbittorrent-wireguard:latest
    container_name: qbittorrent-wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=0
    ports:
      - 8080:8080  # WebUI port
    environment:
      - PUID=568
      - PGID=568
      - UMASK_SET=022
      - WEBUI_PORT=8080
      - VPN_PORT_FORWARD=  # Optional: Set if your VPN provider gives you a forwarded port
    volumes:
      - /mnt/tank/configs/qbittorrent:/config
      - /media:/media
    restart: unless-stopped
```

### Step 5: Start the Container
```bash
docker-compose up -d
```

### Step 6: Access the WebUI

Open your browser and go to `http://localhost:8080` (or `http://your-server-ip:8080`)

**Default credentials:**
- Username: `admin`
- Password: (check the logs on first start with `docker logs qbittorrent-wireguard`)

**Important:** Change the password immediately after first login!

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `568` | User ID `apps` for file permissions |
| `PGID` | `568` | Group ID `apps` for file permissions |
| `UMASK_SET` | `022` | File creation mask |
| `WEBUI_PORT` | `8080` | Port for the web interface |
| `VPN_PORT_FORWARD` | (empty) | Forwarded port from your VPN provider (optional) |

### Port Forwarding

If your VPN provider supports port forwarding (like AirVPN, ProtonVPN, etc.):

1. Get your forwarded port from your VPN provider
2. Set `VPN_PORT_FORWARD` to that port number
3. The container will automatically configure qBittorrent to use it

Example:
```yaml
environment:
  - VPN_PORT_FORWARD=12345
```

## Volumes

| Path | Description |
|------|-------------|
| `/mnt/tank/configs/qbittorrent` | Contains WireGuard config (`wg0.conf`) and qBittorrent settings |
| `/media` | Should container your downloads folder - map this to where you want files saved |

## Network Configuration

The container automatically bypasses the VPN for:
- Local networks (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Tailscale networks (100.64.0.0/10)
- Netbird networks (100.84.0.0/16)

This means:
- ✅ You can access the WebUI from your local network
- ✅ Tailscale/Netbird remote access works
- ✅ All torrent traffic goes through the VPN
- ✅ If VPN drops, torrenting stops immediately

## Verifying the VPN Works

### Check Your IP Address

1. Access the qBittorrent WebUI
2. Go to Settings → Advanced → Network Interface
3. It should show `wg0`
4. Visit a torrent IP checker (like https://ipleak.net/ or https://torguard.net/checkmytorrentipaddress.php)
5. Your IP should match your VPN provider's IP, NOT your home IP

### Test the Killswitch

1. Stop your VPN provider's server (or disconnect internet briefly)
2. Check qBittorrent - all downloads should stop
3. Check logs: `docker logs qbittorrent-wireguard`
4. You should see: `[WARN] Lost VPN connectivity — shutting down.`

## Troubleshooting

### Container won't start

**Check the logs:**
```bash
docker logs qbittorrent-wireguard
```

**Common issues:**
- WireGuard config not found: Make sure `wg0.conf` exists in the config directory
- Permission denied: Check that your `PUID` and `PGID` are correct
- VPN connection failed: Verify your WireGuard config is valid

### Can't access WebUI

If you get a black screen that says `unauthorized` its ok - everything is working. Click the address in the URL bar and hit `ENTER` and you should be prompted for your credentials.

### VPN not connecting

1. Verify your WireGuard config is valid
2. Check if your VPN provider's servers are online
3. Try a different VPN server endpoint
4. Check logs for specific error messages

### Downloads are slow

1. Check if port forwarding is configured (if your VPN supports it)
2. Verify you're connected to a fast VPN server
3. Check qBittorrent connection settings (Settings → Connection)

### Permission errors on downloads

Make sure `PUID` and `PGID` are correct and your `media` dataset has correct permissions **applied recursively!**

## Advanced Usage

### Using with TrueNAS or other NAS

The container works great on NAS systems. Just make sure to:
1. Use the correct paths for your NAS storage
2. Set PUID/PGID to match your NAS user
3. Map volumes to your NAS shares

### Multiple VPN Providers

Want to switch VPN providers? Just replace `wg0.conf` with a new config and restart!

### Viewing Logs

**Live logs:**
```bash
docker logs -f qbittorrent-wireguard
```

**Last 50 lines:**
```bash
docker logs --tail 50 qbittorrent-wireguard
```

### Updating the Container
```bash
docker-compose pull
docker-compose up -d
```

## Security Notes

- ✅ All torrent traffic is encrypted through WireGuard
- ✅ Killswitch prevents leaks if VPN disconnects
- ✅ WebUI is only accessible from local networks by default
- ⚠️ Change the default qBittorrent password immediately
- ⚠️ Keep your WireGuard config file secure (contains private keys)

## Compatible VPN Providers

This container works with any VPN provider that offers WireGuard configs:

- ✅ **[AirVPN](https://airvpn.org/?referred_by=669318)** (with port forwarding) - *Recommended*
- ✅ Mullvad
- ✅ ProtonVPN (with port forwarding)
- ✅ IVPN
- ✅ Windscribe
- ✅ Any WireGuard-compatible provider

## Support This Project

If you find this project helpful, consider supporting its development:

<a href="https://buymeacoffee.com/serversathome" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

Your support helps me maintain this project and create more useful Docker containers and homelab tools!

## Support & Help

Having issues? Check the logs first:
```bash
docker logs qbittorrent-wireguard
```

For issues with:
- **WireGuard connection**: Contact your VPN provider
- **qBittorrent settings**: See [qBittorrent documentation](https://wiki.serversatho.me/en/qBittorrent)
- **Container issues**: Open an issue on GitHub

## Credits

- Built on [linuxserver/qbittorrent](https://github.com/linuxserver/docker-qbittorrent)
- WireGuard by [WireGuard®](https://www.wireguard.com/)
- Inspired by VPN container projects like Gluetun

## License

MIT License - See LICENSE file for details

---

**⚠️ Disclaimer:** This software is provided for educational purposes. Ensure you comply with your VPN provider's terms of service and local laws regarding torrenting and VPN usage.
