#!/usr/bin/env bash
# Interactive production setup for Ubuntu 22.04.
# Generated using the /wizard skill.
set -euo pipefail

# Ensure an interrupted hidden-password prompt never leaves the terminal with
# keyboard echo disabled.
restore_terminal() {
  [[ -t 0 ]] && stty echo 2>/dev/null || true
}
trap restore_terminal EXIT INT TERM

DOMAIN="midnightlibrary.pedrocrlx.pt"
ENV_FILE="${ENV_FILE:-.env}"
TOTAL_STAGES=6
STAGE=0

stage() {
  STAGE=$((STAGE + 1))
  printf '\n\033[1;34m[%s/%s] %s\033[0m\n' "$STAGE" "$TOTAL_STAGES" "$1"
}

confirm() {
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

upsert_env() {
  local key="$1" value="$2" tmp
  touch "$ENV_FILE"
  tmp=$(mktemp)
  grep -vE "^${key}=" "$ENV_FILE" > "$tmp" || true
  printf '%s=%s\n' "$key" "$value" >> "$tmp"
  mv "$tmp" "$ENV_FILE"
}

printf '\nMidnight Library · production setup (%s)\n' "$DOMAIN"
printf 'This wizard configures Cloudflare, secrets, UFW and the Docker stack.\n'
confirm "Continue?" || exit 0

stage "DNS na Cloudflare"
printf 'Abre: https://dash.cloudflare.com/\n'
printf 'Em pedrocrlx.pt → DNS → Records, cria um registo A:\n'
printf '  Name: midnightlibrary | IPv4: IP público desta VPS | Proxy: Proxied (laranja)\n'
read -r -p "IP público da VPS: " VPS_IP
[[ "$VPS_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || { echo "IPv4 inválido"; exit 1; }
confirm "O registo DNS está criado e Proxied?" || exit 1

stage "Cloudflare Origin Certificate"
printf 'Abre: https://dash.cloudflare.com/\n'
printf 'Vai a pedrocrlx.pt → SSL/TLS → Origin Server → Create Certificate.\n'
printf 'Escolhe PEM, inclui %s e guarda o certificado e a chave em ficheiros locais.\n' "$DOMAIN"
DEFAULT_CERT_SOURCE="$HOME/cloudflare-origin-certificate.pem"
DEFAULT_KEY_SOURCE="$HOME/cloudflare-origin-certificate.key"
read -r -p "Caminho do certificado PEM [$DEFAULT_CERT_SOURCE]: " CERT_SOURCE
CERT_SOURCE=${CERT_SOURCE:-$DEFAULT_CERT_SOURCE}
read -r -p "Caminho da chave privada PEM [$DEFAULT_KEY_SOURCE]: " KEY_SOURCE
KEY_SOURCE=${KEY_SOURCE:-$DEFAULT_KEY_SOURCE}
[[ -f "$CERT_SOURCE" && -f "$KEY_SOURCE" ]] || { echo "Certificado ou chave não encontrados"; exit 1; }
mkdir -p secrets
install -m 0644 "$CERT_SOURCE" secrets/cloudflare-origin.pem
install -m 0600 "$KEY_SOURCE" secrets/cloudflare-origin.key

stage "Configuração segura da aplicação"
read -r -p "Nome da base de dados [midnightlibrary]: " POSTGRES_DB
POSTGRES_DB=${POSTGRES_DB:-midnightlibrary}
read -r -p "Utilizador PostgreSQL [midnightlibrary]: " POSTGRES_USER
POSTGRES_USER=${POSTGRES_USER:-midnightlibrary}
read -r -s -p "Password PostgreSQL (Enter para gerar): " POSTGRES_PASSWORD
printf '\n'
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -hex 32)}
DJANGO_SECRET_KEY=$(openssl rand -base64 48 | tr -d '\n')
upsert_env POSTGRES_DB "$POSTGRES_DB"
upsert_env POSTGRES_USER "$POSTGRES_USER"
upsert_env POSTGRES_PASSWORD "$POSTGRES_PASSWORD"
upsert_env POSTGRES_HOST database
upsert_env POSTGRES_PORT 5432
upsert_env DJANGO_SECRET_KEY "$DJANGO_SECRET_KEY"
upsert_env DJANGO_DEBUG false
upsert_env DJANGO_ALLOWED_HOSTS "$DOMAIN"
upsert_env DJANGO_CSRF_TRUSTED_ORIGINS "https://$DOMAIN"
chmod 0600 "$ENV_FILE"
printf 'Configuração guardada em %s com permissões 0600.\n' "$ENV_FILE"

stage "Firewall UFW"
read -r -p "Porta SSH [22]: " SSH_PORT
SSH_PORT=${SSH_PORT:-22}
[[ "$SSH_PORT" =~ ^[0-9]+$ ]] && (( SSH_PORT >= 1 && SSH_PORT <= 65535 )) || { echo "Porta inválida"; exit 1; }
printf 'Será permitido SSH em %s e HTTP/HTTPS apenas a partir da Cloudflare.\n' "$SSH_PORT"
warned="Confirma primeiro que a tua sessão SSH atual usa esta porta. Aplicar regras?"
if confirm "$warned"; then
  sudo ufw allow "${SSH_PORT}/tcp" comment 'SSH'
  while read -r cidr; do
    sudo ufw allow proto tcp from "$cidr" to any port 80 comment 'Cloudflare HTTP'
    sudo ufw allow proto tcp from "$cidr" to any port 443 comment 'Cloudflare HTTPS'
  done < <(curl -fsSL https://www.cloudflare.com/ips-v4)
  while read -r cidr; do
    sudo ufw allow proto tcp from "$cidr" to any port 80 comment 'Cloudflare HTTP IPv6'
    sudo ufw allow proto tcp from "$cidr" to any port 443 comment 'Cloudflare HTTPS IPv6'
  done < <(curl -fsSL https://www.cloudflare.com/ips-v6)
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw --force enable
  sudo install -m 0755 ops/firewall/cloudflare-docker.sh /usr/local/sbin/midnightlibrary-cloudflare-firewall
  sudo install -m 0644 ops/firewall/midnightlibrary-firewall.service /etc/systemd/system/midnightlibrary-firewall.service
  sudo systemctl daemon-reload
  sudo systemctl enable midnightlibrary-firewall.service
  sudo ufw status numbered
else
  echo "Firewall não alterado; não publiques a aplicação antes de o configurar."
  exit 1
fi

stage "Arranque da aplicação"
docker compose -f compose.prod.yaml up -d --build
sudo systemctl restart midnightlibrary-firewall.service
docker compose -f compose.prod.yaml ps
docker compose -f compose.prod.yaml exec app poetry run python django-app/manage.py check --deploy

stage "SSL/TLS e validação"
printf 'Na Cloudflare: SSL/TLS → Overview → seleciona Full (strict).\n'
printf 'Em SSL/TLS → Edge Certificates, ativa Always Use HTTPS.\n'
confirm "Full (strict) está ativo?" || exit 1
printf '\nTestes finais:\n'
curl --fail --silent --show-error --head "https://${DOMAIN}/"
if curl --fail --silent --connect-timeout 5 --resolve "${DOMAIN}:443:${VPS_IP}" "https://${DOMAIN}/" >/dev/null; then
  printf 'Origem responde com o hostname (esperado); o UFW continua a bloquear acessos fora da Cloudflare.\n'
fi
printf '\nSetup concluído: https://%s\n' "$DOMAIN"
