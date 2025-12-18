# Base image (Alpine-based)
FROM linuxserver/qbittorrent:latest

USER root

# Install WireGuard + utilities
RUN apk add --no-cache wireguard-tools iptables iproute2 bash curl

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose WebUI port only (torrent port optional via VPN forwarding)
EXPOSE 8080

# Healthcheck - verify VPN connectivity
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
  CMD ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
