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

# Extract DNS from config before bringing up interface
DNS_SERVERS=$(grep "^DNS" "$WG_CONF" | head -1 | cut -d= -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "1.1.1.1,8.8.8.8")
DNS_SERVERS=$(echo "$DNS_SERVERS" | sed 's/[[:space:]]*,[[:space:]]*/,/g')

echo "[INFO] Configuring DNS: $DNS_SERVERS"

# Set DNS manually before bringing up VPN
echo "# WireGuard DNS" > /etc/resolv.conf
echo "$DNS_SERVERS" | tr ',' '\n' | while read -r dns; do
  [ -n "$dns" ] && echo "nameserver $dns" >> /etc/resolv.conf
done

echo "[INFO] Setting up killswitch firewall BEFORE VPN..."

# Set default policies to DROP before starting VPN
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

# Allow DNS queries
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# Extract VPN endpoint and allow traffic to it
VPN_ENDPOINT=$(grep "^Endpoint" "$WG_CONF" | head -1 | cut -d= -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | cut -d: -f1)
if [ -n "$VPN_ENDPOINT" ]; then
  echo "[INFO] Allowing traffic to VPN endpoint: $VPN_ENDPOINT"
  iptables -A OUTPUT -d "$VPN_ENDPOINT" -j ACCEPT
fi

echo "[INFO] Killswitch active - bringing up VPN interface..."

# Bring up WireGuard interface using wg-quick
wg-quick up "$WG_CONF" || {
  echo "[ERROR] Failed to bring up WireGuard interface."
  exit 1
}

# Wait for interface to be ready
sleep 3

# Verify interface is up
if ! ip link show "$WG_INTERFACE" >/dev/null 2>&1; then
  echo "[ERROR] WireGuard interface $WG_INTERFACE not found after startup"
  wg-quick down "$WG_CONF" 2>/dev/null || true
  exit 1
fi

echo "[INFO] WireGuard interface is up:"
wg show "$WG_INTERFACE"

# Now allow all traffic through VPN interface
iptables -A INPUT -i "$WG_INTERFACE" -j ACCEPT
iptables -A OUTPUT -o "$WG_INTERFACE" -j ACCEPT

echo "[INFO] Firewall rules applied (killswitch active)."

# Check VPN connectivity
echo "[INFO] Testing VPN connectivity..."
if ! ping -c 3 -W 5 "$CHECK_HOST" >/dev/null 2>&1; then
  echo "[ERROR] VPN appears down — cannot reach $CHECK_HOST."
  ip addr show "$WG_INTERFACE"
  ip route show
  wg-quick down "$WG_CONF" 2>/dev/null || true
  exit 1
fi

echo "[INFO] VPN connectivity verified ✓"

# Configure qBittorrent port forwarding if set
if [ -n "$VPN_PORT_FORWARD" ]; then
  echo "[INFO] Setting qBittorrent listen port to $VPN_PORT_FORWARD"
  mkdir -p "$(dirname "$QBIT_CONF")"

  if [ -f "$QBIT_CONF" ]; then
    sed -i '/Connection\\PortRangeMin=/d' "$QBIT_CONF"
    sed -i "/^\[Preferences\]/a Connection\\\\PortRangeMin=$VPN_PORT_FORWARD" "$QBIT_CONF"
  else
    cat > "$QBIT_CONF" << EOF
[Preferences]
Connection\\PortRangeMin=$VPN_PORT_FORWARD
EOF
  fi

  iptables -I INPUT -i "$WG_INTERFACE" -p tcp --dport "$VPN_PORT_FORWARD" -j ACCEPT
  iptables -I INPUT -i "$WG_INTERFACE" -p udp --dport "$VPN_PORT_FORWARD" -j ACCEPT
  
  echo "[INFO] Port forwarding configured for port $VPN_PORT_FORWARD"
fi

echo "[INFO] Starting VPN watchdog in background..."

# Cleanup function
cleanup() {
  echo "[INFO] Shutting down..."
  pkill -15 qbittorrent-nox 2>/dev/null || true
  sleep 2
  pkill -9 qbittorrent-nox 2>/dev/null || true
  wg-quick down "$WG_CONF" 2>/dev/null || true
  exit 0
}

trap cleanup SIGTERM SIGINT

# VPN watchdog
(
  while sleep 60; do
    if ! ping -c 1 -W 3 "$CHECK_HOST" >/dev/null 2>&1; then
      echo "[WARN] Lost VPN connectivity — shutting down."
      pkill -9 qbittorrent-nox || true
      wg-quick down "$WG_CONF" 2>/dev/null || true
      exit 1
    fi
  done
) &

echo "[INFO] Starting qBittorrent WebUI on port $WEBUI_PORT..."
chown -R abc:abc /config 2>/dev/null || true

exec s6-setuidgid abc qbittorrent-nox --webui-port="$WEBUI_PORT"
