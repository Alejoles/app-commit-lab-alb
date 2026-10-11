#!/bin/bash
# Guarda todo lo que ocurre en un log (ayuda a depurar)
exec > >(tee -a /var/log/user-data.log) 2>&1
set -x

# Actualizar paquetes
yum update -y

# Instalar NGINX (amazon-linux-extras solo existe en AL2; en AL2023 entra yum) y Git
amazon-linux-extras install -y nginx1 || yum install -y nginx
yum install -y git

# Iniciar y habilitar NGINX
systemctl start nginx
systemctl enable nginx

# Obtener token IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)

# Obtener datos de la instancia usando el token
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  -s http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_TYPE=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  -s http://169.254.169.254/latest/meta-data/instance-type)

# Endpoint de health check
echo ok > /usr/share/nginx/html/health

# Página básica (se queda si no se puede desplegar la app de GitHub)
cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>ALB + ASG Lab</title>
    <meta http-equiv="refresh" content="2">
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin-top: 50px;
            background-color: #f2f2f2;
        }
        h1 { color: #232F3E; }
        h2 { color: #FF9900; }
    </style>
</head>
<body>
    <h1>Servidor activo</h1>
    <h2>Instance ID: $INSTANCE_ID</h2>
    <p>AZ: $AZ | IP privada: $PRIVATE_IP</p>
</body>
</html>
EOF

# Desplegar la app desde GitHub (si falla, queda la página básica)
REPO_URL="https://github.com/Alejoles/app-commit-lab-alb.git"
if GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$REPO_URL" /opt/alb-asg-lab; then
  export INSTANCE_ID AZ PRIVATE_IP INSTANCE_TYPE
  export COMMIT=$(git -C /opt/alb-asg-lab rev-parse --short HEAD)
  bash /opt/alb-asg-lab/scripts/render.sh || echo "WARN: render.sh falló, se mantiene la página básica"
else
  echo "WARN: no se pudo clonar el repo, se mantiene la página básica"
fi

# Reiniciar NGINX
systemctl restart nginx