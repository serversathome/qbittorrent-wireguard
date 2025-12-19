#!/usr/bin/env bash
set -e

WG_CONF="${WG_CONF:-/config/wg0.conf}"
WG_INTERFACE="wg0"
CHECK_HOST="1.1.1.1"
QBIT_CONF="/config/qBittorrent/qBittorrent.conf"
WEBUI_PORT="${WEBUI_PORT:-8080}"

echo "[INFO] Starting WireGuard VPN setup..."

# Verify config exists
if [ ! -f "$WG_CONF" ]; then
  echo "[ERROR] WireGuard config not found at $WG_CONF"
  exit 1
fi

# Bring up WireGuard interface
echo "[INFO] Bringing up WireGuard interface..."
wg-quick up "$WG_CONF" || {
  echo "[ERROR] Failed to bring up WireGuard interface."
  exit 1
}

# Wait for interface to be ready
sleep 3

# Verify interface is up
if ! ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
  echo "[ERROR] WireGuard interface $WG_INTERFACE not found after startup"
  exit 1
fi

echo "[INFO] Setting up killswitch firewall..."

# Flush old rules
iptables -F
iptables -t nat -F
iptables -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established/related connections
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow local network access (for WebUI and local services)
iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT

iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

# Allow WebUI port from local networks
iptables -A INPUT -p tcp --dport "$WEBUI_PORT" -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport "$WEBUI_PORT" -s 172.16.0.0/12 -j ACCEPT
iptables -A INPUT -p tcp --dport "$WEBUI_PORT" -s 192.168.0.0/16 -j ACCEPT

# Allow all traffic through VPN interface
iptables -A INPUT -i "$WG_INTERFACE" -j ACCEPT
iptables -A OUTPUT -o "$WG_INTERFACE" -j ACCEPT

# Allow DNS (in case it's needed before VPN is fully up)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Everything else is dropped (killswitch active)

echo "[INFO] Firewall rules applied."

# Check VPN connectivity
echo "[INFO] Testing VPN connectivity..."
if ! ping -c 1 -W 5 "$CHECK_HOST" >/dev/null 2>&1; then
  echo "[ERROR] VPN appears down — cannot reach $CHECK_HOST."
  wg-quick down "$WG_CONF"
  exit 1
fi

echo "[INFO] VPN connectivity verified."

# Configure qBittorrent port forwarding if set
if [ -n "$VPN_PORT_FORWARD" ]; then
  echo "[INFO] Setting qBittorrent listen port to $VPN_PORT_FORWARD"
  mkdir -p "$(dirname "$QBIT_CONF")"

  if [ -f "$QBIT_CONF" ]; then
    # Remove existing port config
    sed -i '/Connection\\PortRangeMin=/d' "$QBIT_CONF"
  else
    # Create new config file
    cat > "$QBIT_CONF" << EOF
[Preferences]
Connection\\PortRangeMin=$VPN_PORT_FORWARD
EOF
  fi
  
  # Append port setting
  if grep -q "^\[Preferences\]" "$QBIT_CONF"; then
    sed -i "/^\[Preferences\]/a Connection\\\\PortRangeMin=$VPN_PORT_FORWARD" "$QBIT_CONF"
  fi

  # Allow the forwarded port through firewall
  iptables -I INPUT -i "$WG_INTERFACE" -p tcp --dport "$VPN_PORT_FORWARD" -j ACCEPT
  iptables -I INPUT -i "$WG_INTERFACE" -p udp --dport "$VPN_PORT_FORWARD" -j ACCEPT
  
  echo "[INFO] Port forwarding configured for port $VPN_PORT_FORWARD"
fi

echo "[INFO] Starting VPN watchdog in background..."

# VPN watchdog: monitors connectivity
(
  while sleep 60; do
    if ! ping -c 1 -W 3 "$CHECK_HOST" >/dev/null 2>&1; then
      echo "[WARN] Lost VPN connectivity — shutting down."
      pkill -9 qbittorrent-nox || true
      wg-quick down "$WG_CONF"
      exit 1
    fi
  done
) &

# Start qBittorrent using the base image's s6 infrastructure
echo "[INFO] Starting qBittorrent WebUI on port $WEBUI_PORT..."

# Make sure config directory is owned by abc user
chown -R abc:abc /config 2>/dev/null || true

exec s6-setuidgid abc qbittorrent-nox --webui-port="$WEBUI_PORT"