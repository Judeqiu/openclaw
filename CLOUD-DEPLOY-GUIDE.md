# OpenClaw Cloud VM Deployment Guide

Deploy OpenClaw on a cloud VM (AWS EC2, GCP Compute Engine, Azure VM, DigitalOcean, etc.) using the snapshot backup.

## Overview

| Component       | Requirement                                             |
| --------------- | ------------------------------------------------------- |
| **VM Specs**    | 2+ vCPU, 4GB+ RAM, 20GB+ disk                           |
| **OS**          | Ubuntu 22.04 LTS (recommended) or any Linux with Docker |
| **Network**     | Ports 18789 (gateway), 18790 (bridge) open              |
| **Backup File** | `openclaw-snapshot-20260220_221759.tar.gz` (1.2 GB)     |

---

## Step 1: Prepare the Cloud VM

### Create VM Instance

**AWS EC2 Example:**

```bash
# Instance type: t3.medium (2 vCPU, 4GB RAM) or larger
# AMI: Ubuntu 22.04 LTS
# Security Group: Allow TCP 18789, 18790 from your IP
```

**GCP Compute Engine Example:**

```bash
# Machine type: e2-medium (2 vCPU, 4GB RAM) or larger
# Boot disk: Ubuntu 22.04 LTS, 20GB SSD
# Firewall: Allow ports 18789, 18790
```

**DigitalOcean Example:**

```bash
# Droplet: 2 vCPU / 4GB RAM / 25GB SSD
# Image: Ubuntu 22.04 (LTS) x64
```

### SSH into the VM

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@YOUR-VM-IP
```

---

## Step 2: Install Docker on VM

```bash
# Update package index
sudo apt-get update

# Install prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group (logout and login required after this)
sudo usermod -aG docker $USER
newgrp docker

# Verify installation
docker --version
docker compose version
```

---

## Step 3: Transfer Snapshot to VM

### Option A: SCP (from your local machine)

```bash
# From your Mac, run:
scp -i ~/.ssh/your-key.pem \
  /Users/zhengqingqiu/projects/openclaw/openclaw-snapshot-20260220_221759.tar.gz \
  ubuntu@YOUR-VM-IP:~/
```

### Option B: Download from Cloud Storage

If you uploaded to S3/GCS/Azure Blob:

```bash
# AWS S3 example
aws s3 cp s3://your-bucket/openclaw-snapshot-20260220_221759.tar.gz ~/

# Or use curl/wget with presigned URL
curl -o ~/openclaw-snapshot-20260220_221759.tar.gz "YOUR_PRESIGNED_URL"
```

### Option C: rsync (resumable)

```bash
# Good for slow/unstable connections
rsync -avz --progress \
  -e "ssh -i ~/.ssh/your-key.pem" \
  /Users/zhengqingqiu/projects/openclaw/openclaw-snapshot-20260220_221759.tar.gz \
  ubuntu@YOUR-VM-IP:~/
```

---

## Step 4: Load and Run OpenClaw on VM

### Load the Docker Image

```bash
# SSH into VM
ssh -i ~/.ssh/your-key.pem ubuntu@YOUR-VM-IP

# Verify snapshot file
ls -lh ~/openclaw-snapshot-20260220_221759.tar.gz

# Load the image
docker load -i ~/openclaw-snapshot-20260220_221759.tar.gz

# Verify
docker images | grep openclaw
```

### Create Project Directory

```bash
# Create directory structure
mkdir -p ~/openclaw
cd ~/openclaw

# Create necessary subdirectories
mkdir -p ~/.openclaw
mkdir -p ~/.openclaw/workspace
```

### Create docker-compose.yml

```bash
cat > docker-compose.yml << 'EOF'
services:
  openclaw-gateway:
    image: openclaw:snapshot-20260220_221749
    # DNS workaround for cloud environments
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
      - "cloudflare.com:104.16.132.229"
    environment:
      HOME: /home/node
      TERM: xterm-256color
      # IMPORTANT: Set these via .env file or export them
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
      # Slack Socket Mode
      SLACK_APP_TOKEN: ${SLACK_APP_TOKEN:-}
      SLACK_BOT_TOKEN: ${SLACK_BOT_TOKEN:-}
      # API Keys - set these in .env file
      KIMI_API_KEY: ${KIMI_API_KEY:-}
      BRAVE_API_KEY: ${BRAVE_API_KEY:-}
      # Add other credentials as needed
    volumes:
      - ~/.openclaw:/home/node/.openclaw
      - ~/.openclaw/workspace:/home/node/.openclaw/workspace
    ports:
      - "0.0.0.0:18789:18789"
      - "0.0.0.0:18790:18790"
    init: true
    restart: unless-stopped
    command:
      [
        "node",
        "dist/index.js",
        "gateway",
        "--bind",
        "0.0.0.0",
        "--port",
        "18789",
      ]
EOF
```

### Create Environment File

```bash
# Create .env file with your credentials
cat > .env << 'EOF'
# OpenClaw Configuration
OPENCLAW_GATEWAY_TOKEN=your-secure-token-here
OPENCLAW_GATEWAY_BIND=0.0.0.0
OPENCLAW_GATEWAY_PORT=18789
OPENCLAW_BRIDGE_PORT=18790
OPENCLAW_CONFIG_DIR=~/.openclaw
OPENCLAW_WORKSPACE_DIR=~/.openclaw/workspace

# Slack Configuration (if using Slack)
SLACK_APP_TOKEN=xapp-your-app-token
SLACK_BOT_TOKEN=xoxb-your-bot-token

# API Keys
KIMI_API_KEY=your-kimi-api-key
BRAVE_API_KEY=your-brave-api-key

# Telegram (if using Telegram)
# Set via openclaw config command after starting
EOF

# IMPORTANT: Secure the .env file
chmod 600 .env
```

### Start OpenClaw

```bash
# Start the container
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

---

## Step 5: Configure OpenClaw

### Initial Setup

```bash
# Enter the running container
docker exec -it openclaw-openclaw-gateway-1 sh

# Or run commands directly
docker exec openclaw-openclaw-gateway-1 node /app/openclaw.mjs channels status
```

### Configure Channels

```bash
# Configure Telegram (example)
docker exec openclaw-openclaw-gateway-1 node /app/openclaw.mjs config set channels.telegram.default.token "YOUR_BOT_TOKEN"

# Or use the config file directly
mkdir -p ~/.openclaw
cat > ~/.openclaw/config.json << 'EOF'
{
  "agents": {
    "main": {
      "model": "kimi-coding/kimi-for-coding"
    }
  },
  "channels": {
    "telegram": {
      "default": {
        "token": "YOUR_BOT_TOKEN"
      }
    },
    "slack": {
      "dmPolicy": "open",
      "groupPolicy": "open"
    }
  }
}
EOF
```

### Restart to Apply Config

```bash
docker compose restart
```

---

## Step 6: Network Configuration

### Firewall Rules

**UFW (Ubuntu):**

```bash
sudo ufw allow 18789/tcp
sudo ufw allow 18790/tcp
sudo ufw reload
```

**AWS Security Group:**

```bash
# Allow from your IP only (recommended)
Inbound: TCP 18789 from YOUR_IP/32
Inbound: TCP 18790 from YOUR_IP/32
```

**GCP Firewall:**

```bash
gcloud compute firewall-rules create openclaw-gateway \
  --allow tcp:18789,tcp:18790 \
  --source-ranges=YOUR_IP/32 \
  --target-tags=openclaw
```

### Access OpenClaw Remotely

```bash
# From your local machine, test connection
curl http://YOUR-VM-IP:18789/health

# Or configure local CLI to use remote gateway
openclaw config set gateway.host http://YOUR-VM-IP:18789
openclaw config set gateway.token your-secure-token
```

---

## Step 7: Setup Persistent Storage (Recommended)

### Mount External Disk (AWS EBS, GCP PD, etc.)

```bash
# Check available disks
lsblk

# Format and mount (example with /dev/xvdf)
sudo mkfs -t ext4 /dev/xvdf
sudo mkdir -p /mnt/openclaw-data
sudo mount /dev/xvdf /mnt/openclaw-data

# Make persistent in fstab
echo '/dev/xvdf /mnt/openclaw-data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

# Move OpenClaw data to external disk
sudo mkdir -p /mnt/openclaw-data/.openclaw
sudo chown -R $USER:$USER /mnt/openclaw-data/.openclaw

# Update docker-compose to use new path
# Change ~/.openclaw to /mnt/openclaw-data/.openclaw in volumes
```

---

## Step 8: Setup SSL/HTTPS (Optional but Recommended)

### Using Nginx Reverse Proxy with Let's Encrypt

```bash
# Install nginx and certbot
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Create nginx config
sudo tee /etc/nginx/sites-available/openclaw << 'EOF'
server {
    listen 443 ssl;
    server_name openclaw.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/openclaw.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/openclaw.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:18789;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}

server {
    listen 80;
    server_name openclaw.yourdomain.com;
    return 301 https://$server_name$request_uri;
}
EOF

# Enable site
sudo ln -s /etc/nginx/sites-available/openclaw /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

# Get SSL certificate
sudo certbot --nginx -d openclaw.yourdomain.com
```

---

## Step 9: Monitoring & Maintenance

### Setup Auto-Restart

```bash
# Already configured in docker-compose.yml with restart: unless-stopped
# To check container status:
docker ps

# To view logs:
docker compose logs -f --tail 100
```

### Setup Log Rotation

```bash
# Docker logs can grow large, configure rotation
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

sudo systemctl restart docker
```

### Create Backup Script

```bash
cat > ~/backup-openclaw.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/mnt/openclaw-data/backups

mkdir -p $BACKUP_DIR

# Backup config and data
tar czf $BACKUP_DIR/openclaw-data-$TIMESTAMP.tar.gz ~/.openclaw/

# Backup Docker image
docker save openclaw:snapshot-20260220_221749 | gzip > $BACKUP_DIR/openclaw-image-$TIMESTAMP.tar.gz

# Keep only last 7 backups
ls -t $BACKUP_DIR/*.tar.gz | tail -n +8 | xargs -r rm

echo "Backup completed: $BACKUP_DIR/openclaw-data-$TIMESTAMP.tar.gz"
EOF

chmod +x ~/backup-openclaw.sh

# Add to cron (daily at 2 AM)
(crontab -l 2>/dev/null; echo "0 2 * * * ~/backup-openclaw.sh >> ~/backup.log 2>&1") | crontab -
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs

# Check port conflicts
sudo netstat -tlnp | grep 18789

# Check disk space
df -h
```

### DNS Issues in Cloud

```bash
# Run DNS test
docker exec openclaw-openclaw-gateway-1 /bin/bash /tmp/dns-test.sh

# If DNS fails, check if extra_hosts are in place
docker exec openclaw-openclaw-gateway-1 cat /etc/hosts
```

### Out of Memory

```bash
# Check memory usage
free -h
docker stats --no-stream

# Add swap space if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### High CPU Usage

```bash
# Find process using CPU
docker exec openclaw-openclaw-gateway-1 ps aux --sort=-%cpu | head

# Check logs for errors
docker compose logs -f | grep -i error
```

---

## Quick Commands Reference

```bash
# Start
cd ~/openclaw && docker compose up -d

# Stop
cd ~/openclaw && docker compose down

# Restart
cd ~/openclaw && docker compose restart

# Update image (after loading new snapshot)
cd ~/openclaw && docker compose up -d --force-recreate

# View logs
cd ~/openclaw && docker compose logs -f

# Enter container
docker exec -it openclaw-openclaw-gateway-1 sh

# Check status
docker exec openclaw-openclaw-gateway-1 node /app/openclaw.mjs channels status
```

---

## Security Best Practices

1. **Use firewall rules** - Only allow ports 18789/18790 from trusted IPs
2. **Secure .env file** - `chmod 600 .env`
3. **Use strong tokens** - Generate random gateway tokens
4. **Regular updates** - Keep Docker and host OS updated
5. **Monitor logs** - Watch for unauthorized access attempts
6. **Use SSL** - Always use HTTPS in production with valid certificates

---

_Generated: 2026-02-20_
_For OpenClaw Snapshot: openclaw:snapshot-20260220_221749_
