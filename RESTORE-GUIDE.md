# OpenClaw Docker Snapshot Restore Guide

This guide explains how to restore the OpenClaw Docker container from a snapshot backup.

## Snapshot Information

| Property         | Value                                      |
| ---------------- | ------------------------------------------ |
| **Backup File**  | `openclaw-snapshot-20260220_221759.tar.gz` |
| **Location**     | `/Users/zhengqingqiu/projects/openclaw/`   |
| **Size**         | 1.2 GB (compressed)                        |
| **Created**      | 2026-02-20 22:18                           |
| **Docker Image** | `openclaw:snapshot-20260220_221749`        |

## Prerequisites

- Docker installed and running
- At least 4 GB free disk space (for uncompressed image)
- `docker-compose` or `docker compose` available

---

## Method 1: Restore from Local Docker Image (Fastest)

If the snapshot image is still available in your local Docker:

```bash
# Check if snapshot image exists
docker images | grep openclaw | grep snapshot

# Tag it as the main image
docker tag openclaw:snapshot-20260220_221749 openclaw:local

# Verify
docker images | grep openclaw
```

Then start with docker-compose:

```bash
cd /Users/zhengqingqiu/projects/openclaw
docker compose up -d
```

---

## Method 2: Load from Backup File

If you only have the `.tar.gz` backup file:

### Step 1: Load the Image

```bash
# Navigate to the project directory
cd /Users/zhengqingqiu/projects/openclaw

# Load the Docker image from backup
docker load -i openclaw-snapshot-20260220_221759.tar.gz

# Verify image was loaded
docker images | grep openclaw
```

Expected output:

```
openclaw   snapshot-20260220_221749   3ea783d03492   3.62GB
```

### Step 2: Tag as Local Image

```bash
# Tag the snapshot as the local image (required by docker-compose)
docker tag openclaw:snapshot-20260220_221749 openclaw:local

# Verify
docker images | grep openclaw
```

### Step 3: Start the Container

```bash
# Start with docker-compose
docker compose up -d

# Check status
docker compose ps
```

---

## Method 3: Restore on a Different Machine

To restore on another computer:

### Step 1: Copy the Backup File

```bash
# From source machine
scp /Users/zhengqingqiu/projects/openclaw/openclaw-snapshot-20260220_221759.tar.gz user@target-machine:/path/to/destination/

# Or use any file transfer method (USB, cloud storage, etc.)
```

### Step 2: Load and Run on Target Machine

```bash
# On the target machine

# 1. Load the image
docker load -i openclaw-snapshot-20260220_221759.tar.gz

# 2. Verify
docker images | grep openclaw

# 3. Tag as local
docker tag openclaw:snapshot-20260220_221749 openclaw:local

# 4. Copy docker-compose.yml and config files
cp /path/to/docker-compose.yml .
cp /path/to/.env .

# 5. Start
docker compose up -d
```

---

## Verification

After restoring, verify the container is working:

```bash
# Check container is running
docker ps | grep openclaw

# Check logs
docker logs openclaw-openclaw-gateway-1 | tail -20

# Check channel status
docker exec openclaw-openclaw-gateway-1 node /app/openclaw.mjs channels status

# Run DNS test
docker exec openclaw-openclaw-gateway-1 /bin/bash /tmp/dns-test.sh
```

---

## Troubleshooting

### Issue: "Cannot connect to the Docker daemon"

```bash
# Start Docker Desktop or Docker service
# macOS: Open Docker Desktop app
# Linux: sudo systemctl start docker
```

### Issue: "No such image" after load

```bash
# List all images to find the correct tag
docker images | grep openclaw

# Use the correct tag from output
docker tag openclaw:snapshot-<correct-timestamp> openclaw:local
```

### Issue: "Bind mount failed" when starting

```bash
# Ensure all required directories exist
mkdir -p ~/.openclaw
mkdir -p ~/.openclaw/workspace

# Check docker-compose.yml paths are correct
```

### Issue: Container starts but DNS fails

```bash
# The snapshot includes the code but runtime state (including /etc/hosts entries)
# is created by docker-compose. Ensure your docker-compose.yml has the extra_hosts:

cat docker-compose.yml | grep -A 10 extra_hosts

# If missing, restore from git or recreate with the DNS workaround entries
```

---

## Important Notes

1. **Data Persistence**: The snapshot contains the application image only. User data (configs, sessions, workspace) is stored in volumes and must be backed up separately:
   - `~/.openclaw/` - Configuration and sessions
   - `~/.openclaw/workspace/` - Workspace files

2. **Environment Variables**: The `.env` file with credentials is NOT included in the snapshot. Ensure you have it backed up separately.

3. **Platform Compatibility**: The snapshot was created on macOS (Docker Desktop). It should work on Linux but may have issues with Windows Docker due to path differences.

---

## Quick Reference Commands

```bash
# Full restore process (copy-paste ready)
cd /Users/zhengqingqiu/projects/openclaw
docker load -i openclaw-snapshot-20260220_221759.tar.gz
docker tag openclaw:snapshot-20260220_221749 openclaw:local
docker compose up -d
docker compose ps
```

---

## Backup the Backup

Consider storing the snapshot in multiple locations:

```bash
# External drive
cp openclaw-snapshot-20260220_221759.tar.gz /Volumes/ExternalDrive/backups/

# Cloud storage (example with rclone)
rclone copy openclaw-snapshot-20260220_221759.tar.gz remote:backups/
```

---

_Generated: 2026-02-20_
_Snapshot: openclaw:snapshot-20260220_221749_
