# Migration Guide: v1 to v2 Architecture

## What Changed?

We've completely rewritten the container to properly integrate with the linuxserver.io base image's s6-overlay init system. This fixes several critical issues and makes the container more reliable across different networks.

## Critical Fixes

### 1. **Dynamic Gateway Detection** ✅
**Before**: Hardcoded gateway IP `172.16.2.1` - only worked on specific networks
**After**: Automatically detects your network's gateway - works everywhere

### 2. **Proper PUID/PGID Support** ✅
**Before**: Custom entrypoint bypassed linuxserver's user mapping
**After**: Full PUID/PGID support works correctly

### 3. **WebUI Accessibility** ✅
**Before**: Missing WebUI configuration could cause "unauthorized" errors
**After**: Automatically configures WebUI for proper access

### 4. **Better Killswitch** ✅
**Before**: qBittorrent could start even if VPN failed
**After**: qBittorrent **only** starts after VPN is verified working

## Architecture Changes

### Old Architecture (v1)
```
Custom ENTRYPOINT (/entrypoint.sh)
├── Set up WireGuard
├── Start qBittorrent manually
└── Run watchdog in background
```

**Problems**:
- Bypassed linuxserver.io init system
- Broke PUID/PGID mapping
- Hardcoded network configuration

### New Architecture (v2)
```
linuxserver.io /init (s6-overlay)
├── User setup (PUID/PGID)
├── init-wireguard-vpn (our oneshot service)
│   ├── Dynamic gateway detection
│   ├── WireGuard setup
│   ├── Killswitch firewall
│   ├── LAN bypass routes
│   └── WebUI configuration
├── svc-qbittorrent (linuxserver's service)
│   └── Only starts if VPN succeeded
└── svc-wireguard-watchdog (our monitoring service)
    └── Monitors VPN, kills container if VPN drops
```

**Benefits**:
- Proper integration with base image
- Works on ANY network
- Better error handling
- More maintainable

## Migration Steps

### No Changes Required!

Your existing `docker-compose.yml` works as-is. Just pull the new image:

```bash
docker-compose pull
docker-compose up -d
```

### What Stays The Same

- ✅ Same environment variables (PUID, PGID, WEBUI_PORT, VPN_PORT_FORWARD)
- ✅ Same volume mounts (/config, /media)
- ✅ Same capabilities (NET_ADMIN, SYS_MODULE)
- ✅ Same sysctls
- ✅ Same WireGuard config file location (`/config/wg0.conf`)

### What's Better

1. **Works on all networks**: No more hardcoded gateway issues
2. **Better WebUI access**: Automatically configured for accessibility
3. **Proper permissions**: PUID/PGID actually work now
4. **Stricter security**: qBittorrent won't start if VPN fails
5. **Better logging**: Clear startup messages showing gateway detection

## Verifying the Migration

After pulling the new image, check the logs:

```bash
docker logs qbittorrent-wireguard
```

You should see:
```
========================================
WireGuard VPN Setup
========================================
[INFO] Found WireGuard config at /config/wg0.conf
[INFO] Configuring DNS: 1.1.1.1,8.8.8.8
[INFO] Detected gateway: X.X.X.X via interface: eth0  ← Your actual gateway!
[INFO] Setting up killswitch firewall BEFORE VPN...
[INFO] Allowing traffic to VPN endpoint: ...
[INFO] Killswitch active - bringing up VPN interface...
[INFO] WireGuard interface is up:
[INFO] VPN connectivity verified ✓
========================================
WireGuard VPN Setup Complete ✓
========================================
```

## Troubleshooting

### Container won't start after update

**Check logs**: `docker logs qbittorrent-wireguard`

Common issues:
1. **WireGuard config missing**: Make sure `wg0.conf` is in your config directory
2. **Invalid WireGuard config**: Verify your VPN provider's config is correct
3. **Missing capabilities**: Ensure `NET_ADMIN` and `SYS_MODULE` are set
4. **Missing sysctls**: Ensure both sysctls are configured

### WebUI still shows "unauthorized"

1. Stop the container
2. Edit `/config/qBittorrent/qBittorrent.conf`
3. Under `[Preferences]` section, ensure:
   ```ini
   WebUI\HostHeaderValidation=false
   WebUI\LocalHostAuth=false
   ```
4. Start the container

### PUID/PGID not working

The new version properly respects PUID/PGID. If you're having permission issues:
1. Check your environment variables are set correctly
2. Verify file ownership in volumes: `ls -la /path/to/config`
3. The container will automatically fix permissions on start

## Rollback (if needed)

If you need to rollback to the old version:

```bash
docker pull serversathome/qbittorrent-wireguard:<old-tag>
docker-compose up -d
```

## Questions?

Open an issue on GitHub: https://github.com/serversathome/qbittorrent-wireguard/issues
