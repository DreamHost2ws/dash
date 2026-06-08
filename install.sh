#!/bin/bash
# ╔══════════════════════════════════════════════════════════╗
# ║        LEGACY CLOUD — VPS INSTALLER v1.0                 ║
# ║                  made by devaru007                       ║
# ╚══════════════════════════════════════════════════════════╝

set -e

# ─── Colors ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ─── Banner ───────────────────────────────────────────────
clear
echo -e "${CYAN}"
echo "  ██╗     ███████╗ ██████╗  █████╗  ██████╗██╗   ██╗"
echo "  ██║     ██╔════╝██╔════╝ ██╔══██╗██╔════╝╚██╗ ██╔╝"
echo "  ██║     █████╗  ██║  ███╗███████║██║      ╚████╔╝ "
echo "  ██║     ██╔══╝  ██║   ██║██╔══██║██║       ╚██╔╝  "
echo "  ███████╗███████╗╚██████╔╝██║  ██║╚██████╗   ██║   "
echo "  ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝   ╚═╝   "
echo -e "${NC}"
echo -e "${BOLD}  Legacy Cloud Dashboard — VPS Installer${NC}"
echo -e "  ${YELLOW}https://github.com/DreamHost2ws/dash${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} Installs: Node.js, Nginx, PM2, Legacy Cloud Dashboard"
echo -e "  ${GREEN}✓${NC} Sets up: SSL (Let's Encrypt), Systemd service, Firewall"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""

# ─── Root check ───────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}✗ Please run as root (sudo bash install.sh)${NC}"
  exit 1
fi

# ─── OS Detection ─────────────────────────────────────────
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
  VER=$VERSION_ID
else
  echo -e "${RED}✗ Cannot detect OS${NC}"; exit 1
fi

echo -e "${BLUE}► Detected OS: ${BOLD}$debain${NC}"
echo ""

# ─── Collect Config ───────────────────────────────────────
echo -e "${BOLD}Configuration Setup${NC}"
echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"

read -p "$(echo -e ${BOLD}"  Dashboard Domain (e.g. dash.legacycloud.fun): "${NC})" DOMAIN
read -p "$(echo -e ${BOLD}"  Paid Panel URL (https://paid.legacycloud.fun): "${NC})" PAID_URL
PAID_URL=${PAID_URL:-"https://paid.legacycloud.fun"}
read -p "$(echo -e ${BOLD}"  Free Panel URL (https://free.legacycloud.fun): "${NC})" FREE_URL
FREE_URL=${FREE_URL:-"https://free.legacycloud.fun"}
read -p "$(echo -e ${BOLD}"  Dashboard Port [3000]: "${NC})" PORT
PORT=${PORT:-3000}
read -p "$(echo -e ${BOLD}"  Admin Email (for SSL): "${NC})" ADMIN_EMAIL
read -p "$(echo -e ${BOLD}"  Install SSL with Let's Encrypt? [Y/n]: "${NC})" INSTALL_SSL
INSTALL_SSL=${INSTALL_SSL:-Y}

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Summary:${NC}"
echo -e "  Domain    : ${CYAN}$DOMAIN${NC}"
echo -e "  Paid Panel: ${CYAN}$PAID_URL${NC}"
echo -e "  Free Panel: ${CYAN}$FREE_URL${NC}"
echo -e "  Port      : ${CYAN}$PORT${NC}"
echo -e "  SSL       : ${CYAN}$INSTALL_SSL${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""
read -p "$(echo -e ${BOLD}"  Continue with installation? [Y/n]: "${NC})" CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}► Installation cancelled.${NC}"; exit 0
fi

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  Starting Installation...${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""

step() { echo -e "\n${CYAN}▶${NC} ${BOLD}$1${NC}"; }
ok() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; exit 1; }

# ─── Update System ────────────────────────────────────────
step "Updating system packages"
if [[ $OS == "ubuntu" ]] || [[ $OS == "debian" ]]; then
  apt-get update -q && apt-get upgrade -yq
  apt-get install -yq curl wget git nginx certbot python3-certbot-nginx ufw
  ok "System updated"
elif [[ $OS == "centos" ]] || [[ $OS == "rhel" ]]; then
  yum update -y && yum install -y curl wget git nginx certbot python3-certbot-nginx firewalld
  ok "System updated"
else
  warn "Unknown OS — skipping auto-update. Install curl, git, nginx, certbot manually."
fi

# ─── Install Node.js 20 ───────────────────────────────────
step "Installing Node.js 20 LTS"
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -yq nodejs
  ok "Node.js $(node -v) installed"
else
  ok "Node.js $(node -v) already installed"
fi

# ─── Install PM2 ─────────────────────────────────────────
step "Installing PM2 process manager"
if ! command -v pm2 &>/dev/null; then
  npm install -g pm2 --silent
  ok "PM2 installed"
else
  ok "PM2 already installed"
fi

# ─── Clone / Setup App ────────────────────────────────────
step "Setting up Legacy Cloud dashboard"
INSTALL_DIR="/var/www/legacy-cloud"
if [ -d "$INSTALL_DIR" ]; then
  warn "Directory exists — pulling latest"
  cd "$INSTALL_DIR" && git pull || warn "git pull failed — continuing"
else
  # Try cloning via git first (may prompt for credentials for private repos).
  # Attempt anonymous clone (no password prompt). Fall back to archive download if unavailable.
  if GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://github.com/DreamHost2ws/dash.git "$INSTALL_DIR" 2>/dev/null; then
    ok "Cloned repository to $INSTALL_DIR"
  else
    warn "git clone failed (likely private or unavailable). Falling back to anonymous archive download. No password required."
    mkdir -p "$INSTALL_DIR"
    # Ensure unzip is available
    if ! command -v unzip &>/dev/null; then
      apt-get update -yq || true
      apt-get install -yq unzip || true
    fi
    TMPZIP="/tmp/dash-main.zip"
    curl -fsSL -o "$TMPZIP" https://github.com/DreamHost2ws/dash/archive/refs/heads/main.zip
    unzip -q "$TMPZIP" -d /tmp
    mv /tmp/dash-main/* "$INSTALL_DIR" || true
    rm -f "$TMPZIP"
    ok "Downloaded repository archive to $INSTALL_DIR"
  fi
fi

cd "$INSTALL_DIR"

# ─── Create env config ────────────────────────────────────
step "Writing environment config"
cat > "$INSTALL_DIR/.env" << EOF
NODE_ENV=production
PORT=$PORT
DOMAIN=$DOMAIN
PAID_PANEL_URL=$PAID_URL
FREE_PANEL_URL=$FREE_URL
ADMIN_EMAIL=$ADMIN_EMAIL
EOF
ok ".env created"

# ─── Install dependencies ─────────────────────────────────
step "Installing Node.js dependencies"
if [ -f package.json ]; then
  npm install --production --silent
  ok "Dependencies installed"
else
  warn "No package.json — skipping npm install (static site mode)"
fi

# ─── Update panel URLs in HTML ────────────────────────────
step "Configuring panel links in dashboard"
if [ -f "$INSTALL_DIR/public/index.html" ]; then
  sed -i "s|https://paid.legacycloud.fun|$PAID_URL|g" "$INSTALL_DIR/public/index.html"
  sed -i "s|https://free.legacycloud.fun|$FREE_URL|g" "$INSTALL_DIR/public/index.html"
  ok "Panel URLs configured"
fi

# ─── Nginx Config ─────────────────────────────────────────
step "Configuring Nginx"
cat > /etc/nginx/sites-available/legacy-cloud << NGINX
server {
    listen 80;
    server_name $DOMAIN;

    root $INSTALL_DIR/public;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval' fonts.googleapis.com fonts.gstatic.com" always;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # API proxy (if using Node.js backend)
    location /api/ {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    access_log /var/log/nginx/legacy-cloud.access.log;
    error_log /var/log/nginx/legacy-cloud.error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/legacy-cloud /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
ok "Nginx configured for $DOMAIN"

# ─── SSL ─────────────────────────────────────────────────
if [[ $INSTALL_SSL =~ ^[Yy]$ ]] && [ -n "$DOMAIN" ] && [ -n "$ADMIN_EMAIL" ]; then
  step "Installing SSL certificate (Let's Encrypt)"
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" --redirect
  ok "SSL certificate installed for $DOMAIN"
  # Auto-renew
  (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
  ok "SSL auto-renewal cron added"
else
  warn "Skipping SSL installation"
fi

# ─── Firewall ─────────────────────────────────────────────
step "Configuring UFW firewall"
if command -v ufw &>/dev/null; then
  ufw allow ssh
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
  ok "Firewall configured (SSH, 80, 443)"
fi

# ─── PM2 (if Node.js backend) ────────────────────────────
if [ -f "$INSTALL_DIR/server.js" ]; then
  step "Starting Node.js backend with PM2"
  cd "$INSTALL_DIR"
  pm2 delete legacy-cloud 2>/dev/null || true
  pm2 start server.js --name legacy-cloud --env production
  pm2 save
  pm2 startup systemd -u root --hp /root | tail -1 | bash
  ok "PM2 service started"
fi

# ─── Permissions ─────────────────────────────────────────
step "Setting file permissions"
if [ -d "$INSTALL_DIR/public" ]; then
  chown -R www-data:www-data "$INSTALL_DIR/public" 2>/dev/null || true
  chmod -R 755 "$INSTALL_DIR/public"
  ok "Permissions set for $INSTALL_DIR/public"
else
  warn "Public directory not found at $INSTALL_DIR/public — setting permissions on $INSTALL_DIR instead"
  chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || true
  chmod -R 755 "$INSTALL_DIR" 2>/dev/null || true
  ok "Permissions set for $INSTALL_DIR"
fi

# ─── Done! ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}${BOLD}✓ INSTALLATION COMPLETE!${NC}                              ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Dashboard URL:${NC}  ${CYAN}https://$DOMAIN${NC}"
echo -e "  ${BOLD}Paid Panel:${NC}     ${YELLOW}$PAID_URL${NC}"
echo -e "  ${BOLD}Free Panel:${NC}     ${CYAN}$FREE_URL${NC}"
echo -e "  ${BOLD}Install Dir:${NC}    $INSTALL_DIR"
echo -e "  ${BOLD}Nginx Config:${NC}   /etc/nginx/sites-available/legacy-cloud"
echo -e "  ${BOLD}Error Logs:${NC}     /var/log/nginx/legacy-cloud.error.log"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "  ${CYAN}nginx -t${NC}                   — Test nginx config"
echo -e "  ${CYAN}systemctl reload nginx${NC}     — Reload nginx"
echo -e "  ${CYAN}pm2 logs legacy-cloud${NC}      — View app logs (if Node.js)"
echo -e "  ${CYAN}pm2 restart legacy-cloud${NC}   — Restart app"
echo -e "  ${CYAN}certbot renew${NC}              — Renew SSL"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. Point your DNS A record for ${BOLD}$DOMAIN${NC} → this server's IP"
echo -e "  2. Open your dashboard and go to ${BOLD}Settings${NC}"
echo -e "  3. Enter your Pterodactyl Application API key"
echo -e "  4. Admin access grants automatically if root_admin = true"
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""
