#!/usr/bin/env bash
set -e

WG_CONF="/config/wg0.conf"
WG_INTERFACE="wg0"
CHECK_HOST="1.1.1.1"
QBIT_CONF="/config/qBittorrent/qBittorrent.conf"

# Ensure WireGuard config exists
if [ ! -f "$WG_CONF" ]; then
  echo "[ERROR] WireGuard configuration ($WG_CONF) not found."
  exit 1
fi

echo "[INFO] Bringing up WireGuard interface..."
export WG_QUICK_NO_RESOLVCONF=1
wg-quick up "$WG_CONF" || {
  echo "[ERROR] Failed to bring up WireGuard interface."
  exit 1
}

sleep 3

echo "[INFO] Setting up killswitch firewall..."
# Flush old rules
iptables -F
iptables -t nat -F
iptables -X

# Allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Allow local networks to bypass VPN
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

# Allow VPN traffic only
iptables -A OUTPUT -o "$WG_INTERFACE" -j ACCEPT

# Drop everything else (killswitch)
iptables -A OUTPUT -j DROP

# Optional: set static DNS to ensure container can resolve even if VPN fails
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# Verify initial VPN connectivity
if ! ping -c 1 -W 2 "$CHECK_HOST" >/dev/null 2>&1; then
  echo "[ERROR] VPN appears down — cannot reach $CHECK_HOST."
  wg-quick down "$WG_CONF"
  exit 1
fi

# Configure qBittorrent port if VPN port forward env is set
if [ -n "$VPN_PORT_FORWARD" ]; then
  echo "[INFO] Setting qBittorrent listen port to $VPN_PORT_FORWARD"
  mkdir -p "$(dirname "$QBIT_CONF")"

  if [ -f "$QBIT_CONF" ]; then
    sed -i "/Connection\\\\PortRangeMin=/d" "$QBIT_CONF"
    echo "Connection\\PortRangeMin=$VPN_PORT_FORWARD" >> "$QBIT_CONF"
  else
    echo "[Preferences]" > "$QBIT_CONF"
    echo "Connection\\PortRangeMin=$VPN_PORT_FORWARD" >> "$QBIT_CONF"
  fi

  # Allow the port on VPN interface
  iptables -A INPUT -i "$WG_INTERFACE" -p tcp --dport "$VPN_PORT_FORWARD" -j ACCEPT
  iptables -A INPUT -i "$WG_INTERFACE" -p udp --dport "$VPN_PORT_FORWARD" -j ACCEPT
fi

echo "[INFO] VPN up, killswitch active — starting watchdog..."

# --- VPN watchdog: monitors connectivity every 60s ---
(
  while sleep 60; do
    if ! ping -c 1 -W 2 "$CHECK_HOST" >/dev/null 2>&1; then
      echo "[WARN] Lost VPN connectivity — shutting down qBittorrent."
      wg-quick down "$WG_CONF"
      pkill qbittorrent-nox || true
      exit 1
    else
      echo "[HEALTH] VPN OK"
    fi
  done
) &

# Launch qBittorrent WebUI
echo "[INFO] Starting qBittorrent WebUI on port ${WEBUI_PORT:-8080}..."
exec s6-setuidgid abc qbittorrent-nox --webui-port=${WEBUI_PORT:-8080}
