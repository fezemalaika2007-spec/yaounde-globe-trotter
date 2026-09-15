#!/usr/bin/env bash
set -euo pipefail

DOMAIN="yaoundeglobe.duckdns.org"
VPS_IP="185.202.223.228"
EMAIL="${1:-}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NGINX_SOURCE="${SCRIPT_DIR}/nginx/yaoundeglobe.conf"
NGINX_SITE="/etc/nginx/sites-available/yaoundeglobe"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root: sudo $0 admin@example.com" >&2
  exit 1
fi

if [[ -z "${EMAIL}" ]]; then
  echo "Usage: sudo $0 <certificate-renewal-email>" >&2
  exit 1
fi

if ! getent ahostsv4 "${DOMAIN}" | awk '{print $1}' | grep -Fxq "${VPS_IP}"; then
  echo "${DOMAIN} must point to ${VPS_IP} before requesting a certificate." >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx certbot python3-certbot-nginx

install -m 0644 "${NGINX_SOURCE}" "${NGINX_SITE}"
ln -sfn "${NGINX_SITE}" /etc/nginx/sites-enabled/yaoundeglobe
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable --now nginx
systemctl reload nginx

certbot --nginx \
  --non-interactive \
  --agree-tos \
  --redirect \
  --email "${EMAIL}" \
  -d "${DOMAIN}"

systemctl enable --now certbot.timer
certbot renew --dry-run

echo "HTTPS is configured at https://${DOMAIN}"
