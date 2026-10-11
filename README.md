# app-commit-lab-alb

Aplicación web mínima para un laboratorio de alta disponibilidad en AWS: **Application Load Balancer + Auto Scaling Group + EC2 con NGINX**.

Cada instancia muestra sus propios datos (Instance ID, zona de disponibilidad, IP privada, tipo y commit del código). Al refrescar la página a través del balanceador se ve cómo el tráfico se reparte entre instancias y cómo el Auto Scaling reemplaza las que fallan.

## Cómo se usa

Este repositorio **no se ejecuta a mano**. Lo clona automáticamente el *User Data* de un **Launch Template** cada vez que el Auto Scaling Group lanza una instancia:

1. El ASG lanza una instancia EC2 (Amazon Linux 2023) a partir del Launch Template.
2. El User Data instala NGINX y Git, y consulta los datos de la instancia con **IMDSv2** (token con `PUT` y luego `GET` con el header del token).
3. Clona este repositorio y ejecuta `scripts/[render.sh](http://render.sh)`, que escribe esos datos dentro de `web/index.html` y lo publica en NGINX.
4. NGINX arranca **al final**, de modo que el health check del Target Group solo pasa cuando la página ya está lista.

```text
ASG ──lanza──► EC2 ──User Data──► git clone ──► render.sh ──► NGINX
                                                   │
                                   index.html, info.json y /health

```

## Estructura

```text
alb-asg-lab/
├── web/index.html          # Página con marcadores __INSTANCE_ID__, __AZ__, etc.
├── scripts/render.sh       # Reemplaza los marcadores y publica los archivos
├── userdata/userdata.sh    # User Data que se pega en el Launch Template
├── docs/
|    ├── Arquitectura.png   # Diagrama de Arquitectura
|    ├── Entregable.pdf     # PDF que indica todo lo que había del taller, no incluye enunciados del taller.
└── README.md

```

## Qué publica cada instancia


| Ruta         | Contenido                                                                  |
| ------------ | -------------------------------------------------------------------------- |
| `/`          | Página HTML con los datos de la instancia; se refresca sola cada 2 s       |
| `/info.json` | Los mismos datos en JSON                                                   |
| `/health`    | Responde `ok` con código 200; es la ruta del health check del Target Group |


Los datos se escriben dentro del HTML al arrancar (no se piden con JavaScript en una segunda petición) porque, detrás de un balanceador, dos peticiones seguidas pueden caer en instancias distintas y la página mezclaría datos de ambas.

## Despliegue

1. Crea los Security Groups, el Launch Template, el Target Group, el ALB y el ASG siguiendo la guía del laboratorio.
2. En el Launch Template pega el contenido de `userdata/[userdata.sh](http://userdata.sh)` y cambia la variable `REPO_URL` por la URL de **tu** copia de este repositorio.
3. Exige **IMDSv2** en el Launch Template (*Metadata version: V2 only*).
4. Configura el health check del Target Group con la ruta `/health`.

Requisitos: el repositorio debe ser **público** (se clona sin credenciales) y las instancias necesitan salida a internet para instalar paquetes y clonar.

## Probar en local

```bash
chmod +x scripts/render.sh
WEB_ROOT=/tmp/site INSTANCE_ID=i-0abc123def456 AZ=us-east-1a \
PRIVATE_IP=10.0.1.25 INSTANCE_TYPE=t3.micro COMMIT=abc1234 \
./scripts/render.sh
xdg-open /tmp/site/index.html

```

## Si algo falla

- Si el clon falla, el User Data publica una página mínima con el Instance ID para que el laboratorio siga funcionando.
- Los logs de arranque están en `/var/log/user-data.log` y `/var/log/cloud-init-output.log`.
- El User Data solo corre al **crear** la instancia: si lo cambias, crea una nueva versión del Launch Template y reemplaza las instancias.

## Limpieza

Elimina en este orden: Auto Scaling Group, Application Load Balancer, Target Group, Launch Template y, por último, los Security Groups (`security-ec2` antes que `security-alb`).