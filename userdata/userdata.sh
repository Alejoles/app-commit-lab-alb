#!/bin/bash
set -euxo pipefail
exec > >(tee -a /var/log/user-data.log) 2>&1

REPO_URL="https://github.com/Alejoles/app-commit-lab-alb.git"
WEB_ROOT="/usr/share/nginx/html"

# 1) Paquetes (Amazon Linux 2023 usa dnf)
dnf install -y nginx git

# 2) IMDSv2: primero un token con PUT, luego cada consulta lleva el token en un header
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 600")
md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  "http://169.254.169.254/latest/meta-data/$1"; }

export INSTANCE_ID=$(md instance-id)
export AZ=$(md placement/availability-zone)
export PRIVATE_IP=$(md local-ipv4)
export INSTANCE_TYPE=$(md instance-type)
export WEB_ROOT

# 3) Código de la app desde GitHub
if git clone --depth 1 "$REPO_URL" "$APP_DIR"; then
  export COMMIT=$(git -C "$APP_DIR" rev-parse --short HEAD)
  bash "$APP_DIR/scripts/render.sh"
else
  echo "WARN: no se pudo clonar el repo; se publica una pagina minima"
  echo "<meta http-equiv='refresh' content='2'><h1>Servidor activo</h1><h2>Instance ID: $INSTANCE_ID</h2><p>AZ: $AZ</p>" > "$WEB_ROOT/index.html"
  echo ok > "$WEB_ROOT/health"
fi

# 4) NGINX arranca al final: el health check solo pasa cuando todo está listo
systemctl enable --now nginx