FROM linuxserver/qbittorrent:latest

USER root

# Install WireGuard + utilities (remove openresolv)
RUN apk add --no-cache wireguard-tools iptables ip6tables iproute2 bash curl

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose WebUI port
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
  CMD ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/entrypoint.sh"]