#!/bin/bash
# ╔══════════════════════════════════════════════════════════╗
# ║        LEGACY CLOUD — VPS INSTALLER v2.0 MOBILE         ║
# ║        https://legacycloud.fun                          ║
# ║        Optimized for Phone & Mobile Access              ║
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
echo -e "${BOLD}  Legacy Cloud Dashboard — Mobile Installer${NC}"
echo -e "  ${YELLOW}https://github.com/DreamHost2ws/dash${NC}"
echo ""
echo -e "  ${GREEN}✓${NC} Mobile-optimized responsive design"
echo -e "  ${GREEN}✓${NC} Custom .jpg backgrounds with video support"
echo -e "  ${GREEN}✓${NC} Touch-friendly interface"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""

# ─── Root check ───────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}✗ Please run as root (sudo bash install-mobile.sh)${NC}"
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

echo -e "${BLUE}► Detected OS: ${BOLD}$PRETTY_NAME${NC}"
echo ""

# ─── Collect Config ───────────────────────────────────────
echo -e "${BOLD}Configuration Setup${NC}"
echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"

read -p "$(echo -e ${BOLD}"  Dashboard Domain (e.g. dash.legacycloud.fun): "${NC})" DOMAIN
read -p "$(echo -e ${BOLD}"  Panel URL (https://panel.legacycloud.fun): "${NC})" PANEL_URL
PANEL_URL=${PANEL_URL:-"https://panel.legacycloud.fun"}
read -p "$(echo -e ${BOLD}"  Dashboard Port [3000]: "${NC})" PORT
PORT=${PORT:-3000}
read -p "$(echo -e ${BOLD}"  Admin Email (for SSL): "${NC})" ADMIN_EMAIL
read -p "$(echo -e ${BOLD}"  Database URL (MongoDB): "${NC})" DB_URL
read -p "$(echo -e ${BOLD}"  API Secret Key: "${NC})" API_SECRET

# ─── Background Configuration ─────────────────────────────
echo ""
echo -e "${BOLD}Background Configuration${NC}"
echo -e "${CYAN}──────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "  ${CYAN}Select background type:${NC}"
echo -e "  1) URL-based background (.jpg)"
echo -e "  2) Video background (.mp4/.webm)"
echo -e "  3) Gradient (no background file)"
read -p "$(echo -e ${BOLD}"  Background type [1-3, default 1]: "${NC})" BG_TYPE
BG_TYPE=${BG_TYPE:-1}

BG_IMAGE_URL=""
BG_VIDEO_URL=""
BG_VIDEO_TYPE=""

if [ "$BG_TYPE" = "1" ]; then
  read -p "$(echo -e ${BOLD}"  Background image URL (.jpg): "${NC})" BG_IMAGE_URL
  BG_IMAGE_URL=${BG_IMAGE_URL:-"https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1920&h=1080&fit=crop"}
elif [ "$BG_TYPE" = "2" ]; then
  read -p "$(echo -e ${BOLD}"  Video background URL (.mp4 or .webm): "${NC})" BG_VIDEO_URL
  read -p "$(echo -e ${BOLD}"  Video type (mp4 or webm): "${NC})" BG_VIDEO_TYPE
  BG_VIDEO_TYPE=${BG_VIDEO_TYPE:-"mp4"}
fi

read -p "$(echo -e ${BOLD}"  Install SSL with Let's Encrypt? [Y/n]: "${NC})" INSTALL_SSL
INSTALL_SSL=${INSTALL_SSL:-Y}

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Summary:${NC}"
echo -e "  Domain       : ${CYAN}$DOMAIN${NC}"
echo -e "  Panel URL    : ${CYAN}$PANEL_URL${NC}"
echo -e "  Port         : ${CYAN}$PORT${NC}"
echo -e "  Background   : ${CYAN}Type $BG_TYPE${NC}"
echo -e "  SSL          : ${CYAN}$INSTALL_SSL${NC}"
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
  apt-get install -yq curl wget git nginx certbot python3-certbot-nginx ufw imagemagick ffmpeg
  ok "System updated (with imagemagick & ffmpeg)"
elif [[ $OS == "centos" ]] || [[ $OS == "rhel" ]]; then
  yum update -y && yum install -y curl wget git nginx certbot python3-certbot-nginx firewalld imagemagick ffmpeg
  ok "System updated"
else
  warn "Unknown OS — skipping auto-update. Install curl, git, nginx, certbot, imagemagick, ffmpeg manually."
fi

# ─── Install Node.js 20 ───────────────────────────────────
step "Installing Node.js 20 LTS"
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - 2>/dev/null || true
  apt-get install -yq nodejs 2>/dev/null || yum install -y nodejs 2>/dev/null || true
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
  if GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://github.com/DreamHost2ws/dash.git "$INSTALL_DIR" 2>/dev/null; then
    ok "Cloned repository to $INSTALL_DIR"
  else
    warn "git clone failed. Falling back to anonymous archive download."
    mkdir -p "$INSTALL_DIR"
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
PANEL_URL=$PANEL_URL
ADMIN_EMAIL=$ADMIN_EMAIL
MONGODB_URI=$DB_URL
API_SECRET=$API_SECRET
BG_TYPE=$BG_TYPE
BG_IMAGE_URL=$BG_IMAGE_URL
BG_VIDEO_URL=$BG_VIDEO_URL
BG_VIDEO_TYPE=$BG_VIDEO_TYPE
MOBILE_ENABLED=true
RESPONSIVE_DESIGN=true
EOF
ok ".env created with mobile config"

# ─── Install dependencies ─────────────────────────────────
step "Installing Node.js dependencies"
if [ -f package.json ]; then
  npm install --production --silent
  ok "Dependencies installed"
else
  warn "No package.json — skipping npm install (static site mode)"
fi

# ─── Create Mobile Assets Directory ─────────────────────────
step "Creating mobile assets directories"
mkdir -p "$INSTALL_DIR/public/assets/backgrounds"
mkdir -p "$INSTALL_DIR/public/assets/videos"
mkdir -p "$INSTALL_DIR/public/assets/fonts"
ok "Asset directories created"

# ─── Download/Process Background Image ────────────────────
if [ "$BG_TYPE" = "1" ] && [ -n "$BG_IMAGE_URL" ]; then
  step "Processing background image for mobile"
  BG_PATH="$INSTALL_DIR/public/assets/backgrounds/bg-main.jpg"
  
  if curl -fsSL -o "$BG_PATH" "$BG_IMAGE_URL" 2>/dev/null; then
    # Optimize for mobile (resize to common mobile widths)
    if command -v convert &>/dev/null; then
      convert "$BG_PATH" -resize 1080x1920 -quality 85 "$INSTALL_DIR/public/assets/backgrounds/bg-mobile.jpg"
      convert "$BG_PATH" -resize 1440x2560 -quality 85 "$INSTALL_DIR/public/assets/backgrounds/bg-tablet.jpg"
      ok "Background optimized for mobile (1080p, tablet 1440p)"
    else
      ok "Background downloaded (imagemagick not available for optimization)"
    fi
  else
    warn "Could not download background image from URL"
  fi
fi

# ─── Download/Process Video Background ──────────────────
if [ "$BG_TYPE" = "2" ] && [ -n "$BG_VIDEO_URL" ]; then
  step "Processing video background"
  VID_PATH="$INSTALL_DIR/public/assets/videos/bg-video.$BG_VIDEO_TYPE"
  
  if curl -fsSL -o "$VID_PATH" "$BG_VIDEO_URL" 2>/dev/null; then
    # Convert to multiple formats if ffmpeg available
    if command -v ffmpeg &>/dev/null; then
      if [ "$BG_VIDEO_TYPE" = "mp4" ]; then
        ffmpeg -i "$VID_PATH" -c:v libvpx-vp9 -crf 30 -b:v 0 "$INSTALL_DIR/public/assets/videos/bg-video.webm" 2>/dev/null || true
        ok "Video converted to WebM format for better compression"
      fi
    fi
  else
    warn "Could not download video from URL"
  fi
fi

# ─── Create Mobile-Optimized Config ──────────────────────
step "Creating mobile dashboard settings"
mkdir -p "$INSTALL_DIR/config"
cat > "$INSTALL_DIR/config/dashboard-settings.json" << 'SETTINGS'
{
  "dashboard": {
    "title": "Legacy Cloud",
    "logo": "/assets/logo.png",
    "favicon": "/assets/favicon.ico",
    "theme": "dark",
    "language": "en",
    "mobile_first": true,
    "responsive_breakpoints": {
      "mobile": 480,
      "tablet": 768,
      "desktop": 1024
    }
  },
  "general": {
    "maintenance_mode": false,
    "maintenance_message": "System under maintenance. Please try again later.",
    "enable_registration": true,
    "require_email_verification": true,
    "session_timeout": 3600,
    "mobile_session_timeout": 1800
  },
  "security": {
    "enable_2fa": true,
    "password_min_length": 8,
    "password_require_numbers": true,
    "password_require_special_chars": true,
    "api_rate_limit": 100
  },
  "mobile": {
    "enable_touch_gestures": true,
    "enable_haptic_feedback": true,
    "bottom_navigation": true,
    "large_touch_targets": true,
    "font_size_multiplier": 1.1
  },
  "background": {
    "type": "image",
    "blur_effect": true,
    "overlay_opacity": 0.5,
    "overlay_color": "#000000"
  },
  "email": {
    "smtp_host": "smtp.gmail.com",
    "smtp_port": 587,
    "smtp_secure": true,
    "smtp_user": "your-email@gmail.com",
    "smtp_password": "your-app-password"
  }
}
SETTINGS
ok "Mobile dashboard settings created"

# ─── Create Paid Services Config ────────────────────────
step "Creating paid services configuration"
cat > "$INSTALL_DIR/config/paid-services.json" << 'SERVICES'
{
  "services": [
    {
      "id": "basic",
      "name": "Basic",
      "description": "Entry-level service",
      "price": 9.99,
      "currency": "USD",
      "billing_cycle": "monthly",
      "features": [
        "Email support",
        "Basic analytics",
        "2GB storage"
      ]
    },
    {
      "id": "professional",
      "name": "Professional",
      "description": "Advanced features",
      "price": 29.99,
      "currency": "USD",
      "billing_cycle": "monthly",
      "features": [
        "Priority support",
        "Advanced analytics",
        "50GB storage",
        "API access"
      ]
    },
    {
      "id": "enterprise",
      "name": "Enterprise",
      "description": "Full-featured service",
      "price": 99.99,
      "currency": "USD",
      "billing_cycle": "monthly",
      "features": [
        "24/7 dedicated support",
        "Custom analytics",
        "Unlimited storage",
        "API access",
        "Custom domain",
        "White-label options"
      ]
    }
  ],
  "payment_methods": [
    "credit_card",
    "paypal",
    "stripe"
  ],
  "tax_enabled": true,
  "tax_percentage": 0
}
SERVICES
ok "Paid services configured"

# ─── Create Server Ranks Config ──────────────────────────
step "Creating server ranks configuration"
cat > "$INSTALL_DIR/config/server-ranks.json" << 'RANKS'
{
  "ranks": [
    {
      "id": 1,
      "name": "Starter",
      "description": "Perfect for small projects",
      "icon": "🚀",
      "color": "#3498db",
      "ram_gb": 1,
      "disk_gb": 20,
      "cpu_cores": 1,
      "bandwidth_gb": 100,
      "player_slots": 10,
      "databases": 1,
      "backup_slots": 2,
      "price_monthly": 4.99,
      "price_annual": 49.99
    },
    {
      "id": 2,
      "name": "Growth",
      "description": "For growing communities",
      "icon": "📈",
      "color": "#2ecc71",
      "ram_gb": 2,
      "disk_gb": 50,
      "cpu_cores": 2,
      "bandwidth_gb": 250,
      "player_slots": 25,
      "databases": 3,
      "backup_slots": 5,
      "price_monthly": 9.99,
      "price_annual": 99.99
    },
    {
      "id": 3,
      "name": "Professional",
      "description": "For established servers",
      "icon": "⭐",
      "color": "#f39c12",
      "ram_gb": 4,
      "disk_gb": 100,
      "cpu_cores": 4,
      "bandwidth_gb": 500,
      "player_slots": 50,
      "databases": 5,
      "backup_slots": 10,
      "price_monthly": 19.99,
      "price_annual": 199.99
    },
    {
      "id": 4,
      "name": "Enterprise",
      "description": "Maximum performance",
      "icon": "👑",
      "color": "#e74c3c",
      "ram_gb": 8,
      "disk_gb": 200,
      "cpu_cores": 8,
      "bandwidth_gb": 1000,
      "player_slots": 100,
      "databases": 10,
      "backup_slots": 20,
      "price_monthly": 49.99,
      "price_annual": 499.99
    }
  ]
}
RANKS
ok "Server ranks created"

# ─── Nginx Config (Mobile Optimized) ──────────────────────
step "Configuring Nginx for mobile"
cat > /etc/nginx/sites-available/legacy-cloud << NGINX
# Mobile-Optimized Nginx Configuration
server {
    listen 80;
    server_name $DOMAIN;

    root $INSTALL_DIR/public;
    index index.html;

    # Mobile viewport and responsive headers
    add_header Viewport "width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes";
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' https: data: 'unsafe-inline' 'unsafe-eval' fonts.googleapis.com fonts.gstatic.com;" always;

    # CORS headers for mobile
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # API proxy
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

    # Settings API
    location /api/settings/ {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_cache_bypass \$http_upgrade;
    }

    # Services API
    location /api/services/ {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_cache_bypass \$http_upgrade;
    }

    # Ranks API
    location /api/ranks/ {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_cache_bypass \$http_upgrade;
    }

    # Gzip compression (important for mobile)
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Video caching
    location ~* \.(mp4|webm)$ {
        expires 30d;
        add_header Cache-Control "public";
    }

    access_log /var/log/nginx/legacy-cloud.access.log;
    error_log /var/log/nginx/legacy-cloud.error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/legacy-cloud /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
ok "Nginx configured for mobile"

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
  ok "Firewall configured"
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
chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || true
chmod -R 755 "$INSTALL_DIR/public"
chmod -R 755 "$INSTALL_DIR/config"
ok "Permissions set"

# ─── Done! ───────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}${BOLD}✓ MOBILE INSTALLATION COMPLETE!${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Dashboard URL:${NC}  ${CYAN}https://$DOMAIN${NC}"
echo -e "  ${BOLD}Panel URL:${NC}      ${YELLOW}$PANEL_URL${NC}"
echo -e "  ${BOLD}Install Dir:${NC}    $INSTALL_DIR"
echo -e "  ${BOLD}Config Dir:${NC}     $INSTALL_DIR/config"
echo -e "  ${BOLD}Assets Dir:${NC}     $INSTALL_DIR/public/assets"
echo ""
echo -e "  ${BOLD}Mobile Features:${NC}"
echo -e "  ${CYAN}• Responsive design (mobile/tablet/desktop)${NC}"
echo -e "  ${CYAN}• Touch-friendly interface${NC}"
echo -e "  ${CYAN}• Optimized background images${NC}"
if [ "$BG_TYPE" = "2" ]; then
  echo -e "  ${CYAN}• Video background support${NC}"
fi
echo -e "  ${CYAN}• Mobile-optimized fonts and sizing${NC}"
echo ""
echo -e "  ${BOLD}Configuration Files:${NC}"
echo -e "  ${CYAN}• Dashboard Settings:${NC} $INSTALL_DIR/config/dashboard-settings.json"
echo -e "  ${CYAN}• Paid Services:${NC}      $INSTALL_DIR/config/paid-services.json"
echo -e "  ${CYAN}• Server Ranks:${NC}       $INSTALL_DIR/config/server-ranks.json"
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
echo ""
