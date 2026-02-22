#!/bin/bash
#
# OpenClaw Cloud VM Deployment Script
# Run this on your cloud VM after transferring the snapshot
#

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  OpenClaw Cloud Deployment Script${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if snapshot exists
if [ ! -f "$HOME/openclaw-snapshot-20260220_221759.tar.gz" ]; then
    echo -e "${RED}Error: Snapshot file not found!${NC}"
    echo "Please transfer the snapshot first:"
    echo "  scp openclaw-snapshot-20260220_221759.tar.gz ubuntu@$(curl -s ifconfig.me):~/"
    exit 1
fi

echo "✓ Snapshot file found"

# Create directories
echo ""
echo "Creating directories..."
mkdir -p ~/openclaw ~/.openclaw ~/.openclaw/workspace
cd ~/openclaw

# Load Docker image
echo ""
echo "Loading Docker image (this may take a minute)..."
docker load -i ~/openclaw-snapshot-20260220_221759.tar.gz

echo ""
echo "✓ Image loaded successfully"
docker images | grep openclaw

# Create docker-compose.yml
echo ""
echo "Creating docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
services:
  openclaw-gateway:
    image: openclaw:snapshot-20260220_221749
    extra_hosts:
      - "slack.com:3.0.66.145"
      - "wss-primary.slack.com:54.151.204.41"
      - "api.telegram.org:149.154.167.220"
      - "api.notion.com:208.103.161.1"
      - "smtp.gmail.com:142.251.10.108"
      - "www.googleapis.com:64.233.170.95"
      - "moltbook.com:13.33.45.90"
      - "google.com:142.251.10.138"
      - "github.com:20.205.243.166"
    environment:
      HOME: /home/node
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
      SLACK_APP_TOKEN: ${SLACK_APP_TOKEN:-}
      SLACK_BOT_TOKEN: ${SLACK_BOT_TOKEN:-}
      KIMI_API_KEY: ${KIMI_API_KEY:-}
      BRAVE_API_KEY: ${BRAVE_API_KEY:-}
    volumes:
      - ~/.openclaw:/home/node/.openclaw
      - ~/.openclaw/workspace:/home/node/.openclaw/workspace
    ports:
      - "0.0.0.0:18789:18789"
      - "0.0.0.0:18790:18790"
    restart: unless-stopped
    command: ["node", "dist/index.js", "gateway", "--bind", "0.0.0.0", "--port", "18789"]
EOF

echo "✓ docker-compose.yml created"

# Create .env if it doesn't exist
if [ ! -f .env ]; then
    echo ""
    echo "Creating .env file..."
    cat > .env << 'EOF'
# OpenClaw Configuration
# IMPORTANT: Change these values!

OPENCLAW_GATEWAY_TOKEN=change-me-to-secure-token-$(openssl rand -hex 8)

# Add your API keys below:
# KIMI_API_KEY=your-key-here
# BRAVE_API_KEY=your-key-here
# SLACK_APP_TOKEN=xapp-your-token
# SLACK_BOT_TOKEN=xoxb-your-token
EOF
    chmod 600 .env
    echo -e "${YELLOW}✓ .env file created - PLEASE EDIT IT with your actual credentials!${NC}"
else
    echo "✓ .env file already exists"
fi

# Open firewall ports
echo ""
echo "Opening firewall ports..."
if command -v ufw &> /dev/null; then
    sudo ufw allow 18789/tcp || true
    sudo ufw allow 18790/tcp || true
    echo "✓ UFW ports opened"
fi

if command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port=18789/tcp || true
    sudo firewall-cmd --permanent --add-port=18790/tcp || true
    sudo firewall-cmd --reload || true
    echo "✓ firewalld ports opened"
fi

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR-VM-IP")

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Edit your .env file and add your API credentials:"
echo "   nano ~/openclaw/.env"
echo ""
echo "2. Start OpenClaw:"
echo "   cd ~/openclaw && docker compose up -d"
echo ""
echo "3. Check status:"
echo "   docker compose ps"
echo "   docker compose logs -f"
echo ""
echo "4. Configure channels (if needed):"
echo "   docker exec openclaw-openclaw-gateway-1 node /app/openclaw.mjs channels status"
echo ""
echo "Your VM public IP: $PUBLIC_IP"
echo "OpenClaw will be available at: http://$PUBLIC_IP:18789"
echo ""
echo -e "${YELLOW}Remember to open ports 18789 and 18790 in your cloud provider's firewall!${NC}"
