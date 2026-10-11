#!/bin/bash
# Uso: INSTANCE_ID=... AZ=... PRIVATE_IP=... INSTANCE_TYPE=... COMMIT=... ./render.sh
set -euo pipefail
: "${INSTANCE_ID:?}" "${AZ:?}" "${PRIVATE_IP:?}" "${INSTANCE_TYPE:?}" "${COMMIT:?}"

WEB_ROOT="${WEB_ROOT:-/usr/share/nginx/html}"
APP_DIR="/opt/alb-asg-lab"
SRC="$(cd "$(dirname "$0")/../web" && pwd)"

mkdir -p "$WEB_ROOT"
cp -r --remove-destination "$SRC"/. "$WEB_ROOT"/

sed -i \
  -e "s|__INSTANCE_ID__|$INSTANCE_ID|g" \
  -e "s|__AZ__|$AZ|g" \
  -e "s|__PRIVATE_IP__|$PRIVATE_IP|g" \
  -e "s|__INSTANCE_TYPE__|$INSTANCE_TYPE|g" \
  -e "s|__COMMIT__|$COMMIT|g" \
  "$WEB_ROOT/index.html"

cat > "$WEB_ROOT/info.json" <<EOF
{"instance_id":"$INSTANCE_ID","az":"$AZ","private_ip":"$PRIVATE_IP","instance_type":"$INSTANCE_TYPE","commit":"$COMMIT"}
EOF

# Endpoint de health check: solo existe cuando la página ya está lista
echo ok > "$WEB_ROOT/health"