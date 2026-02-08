# Credential Management for OpenClaw Docker

This document explains how credentials are managed in the OpenClaw Docker setup.

## Overview

OpenClaw integrates with many external services (Notion, Gmail, Twitter, etc.). This setup uses a **tiered credential management strategy** to keep credentials secure while making them available to the container.

---

## Three-Tier Strategy

### Tier 1: File-Based Credentials (Persistent Mounts)

**Best for:** OAuth tokens, service account keys, multi-file credential sets

**How it works:**

- Credentials are stored on the host in `~/.config/<service>/`
- Docker mounts these directories into the container
- Persists across container rebuilds

**Services using this:**

| Service      | Host Location                                         | Container Location                    |
| ------------ | ----------------------------------------------------- | ------------------------------------- |
| Notion       | `~/.config/notion/token.txt`                          | `/home/node/.config/notion/token.txt` |
| Google Cloud | `~/.config/gcloud/`                                   | `/home/node/.config/gcloud/`          |
| AWS          | `~/.aws/credentials`                                  | `/home/node/.aws/credentials`         |
| Moltbook     | `~/.openclaw/workspace/.config/moltbook/`             | (already persisted)                   |
| Calendar     | `~/.openclaw/workspace/skills/calendar-intelligence/` | (already persisted)                   |

**Setup:**

```bash
# Notion example
mkdir -p ~/.config/notion
echo "secret_xxx" > ~/.config/notion/token.txt
chmod 600 ~/.config/notion/token.txt
```

---

### Tier 2: Environment Variables

**Best for:** Simple API keys, tokens that fit in a single string

**How it works:**

- Credentials are stored in `.env.credentials` (gitignored)
- Docker Compose passes them to the container as environment variables
- Easy to rotate, no file permissions to manage

**Services using this:**

| Variable             | Service            | Get From                       |
| -------------------- | ------------------ | ------------------------------ |
| `BRAVE_API_KEY`      | Web Search         | https://api.search.brave.com   |
| `MEMORY_BOT_TOKEN`   | Memory Trainer Bot | @BotFather on Telegram         |
| `GMAIL_APP_PASSWORD` | Email              | Google Account → App Passwords |
| `TWITTER_AUTH_TOKEN` | X/Twitter          | Browser cookies (auth_token)   |
| `TWITTER_CT0`        | X/Twitter          | Browser cookies (ct0)          |
| `POLYMARKET_API_KEY` | Polymarket         | Polymarket API settings        |

**Setup:**

```bash
# 1. Copy the example file
cp .env.credentials.example .env.credentials

# 2. Edit .env.credentials with your actual values
nano .env.credentials

# 3. Source the file in your shell
source .env.credentials
```

---

### Tier 3: OpenClaw Native Auth

**Best for:** Core OpenClaw functionality (models, channels)

**How it works:**

- Stored in `~/.openclaw/` directory
- Already persisted via Docker volume mount
- Managed by OpenClaw CLI/commands

**Services:**

| Service           | Location                    | How to Set Up             |
| ----------------- | --------------------------- | ------------------------- |
| Moonshot/Kimi API | `~/.openclaw/openclaw.json` | `openclaw models add`     |
| Telegram          | `~/.openclaw/credentials/`  | `openclaw channels login` |
| Device Identity   | `~/.openclaw/identity/`     | Auto-generated            |

---

## Quick Start: Fix Missing Credentials

### Check Current Status

```bash
./scripts/check-credentials.sh
```

### Fix Notion Token (Most Common Issue)

```bash
# 1. Create directory on host
mkdir -p ~/.config/notion

# 2. Add your token (get from https://www.notion.so/my-integrations)
echo "secret_xxxxxxxxxx" > ~/.config/notion/token.txt
chmod 600 ~/.config/notion/token.txt

# 3. Restart container to pick up the mount
docker compose restart openclaw-gateway
```

### Fix Environment Variables

```bash
# 1. Copy example file
cp .env.credentials.example .env.credentials

# 2. Edit with your values
nano .env.credentials

# 3. Restart container
docker compose down
docker compose up -d openclaw-gateway
```

---

## Security Best Practices

### 1. File Permissions

Always set restrictive permissions on credential files:

```bash
chmod 600 ~/.config/notion/token.txt
chmod 600 ~/.aws/credentials
chmod 600 .env.credentials
```

### 2. Never Commit Credentials

The following are already gitignored:

- `.env.credentials`
- `.env.credentials.*`
- `~/.config/*` (outside project)
- `~/.openclaw/` (outside project)

### 3. Rotate Regularly

- API keys should be rotated every 90 days
- Use separate integrations for different environments
- Revoke unused tokens

### 4. Backup Strategy

Back up your credentials securely:

```bash
# Create encrypted backup
zip -e credentials-backup.zip ~/.config/ ~/.openclaw/credentials/

# Or use 1Password/Bitwarden for individual tokens
```

---

## Troubleshooting

### "Token not found" after container rebuild

**Cause:** Token was stored inside the old container, not on the host.

**Fix:** Use file-based credentials (Tier 1) instead of storing inside container.

### Environment variables not available in container

**Cause:** `.env.credentials` not loaded or variables not exported.

**Fix:**

```bash
# Check if variables are set on host
env | grep BRAVE

# If not, source the file
export $(grep -v '^#' .env.credentials | xargs)

# Then restart container
docker compose down && docker compose up -d
```

### Permission denied when reading credentials

**Cause:** File permissions too restrictive or ownership issues.

**Fix:**

```bash
# Fix ownership
sudo chown -R $(whoami) ~/.config/notion

# Set correct permissions
chmod 600 ~/.config/notion/token.txt
```

---

## Service-Specific Setup

### Notion

1. Visit https://www.notion.so/my-integrations
2. Create new integration
3. Copy "Internal Integration Token"
4. Save to `~/.config/notion/token.txt`

### Brave Search

1. Visit https://api.search.brave.com/app/keys
2. Create API key
3. Add to `.env.credentials`: `BRAVE_API_KEY=your_key`

### Google Calendar

1. Go to Google Cloud Console
2. Create OAuth credentials
3. Download `credentials.json` to skill folder
4. Run OAuth flow (may need to do this on host first)

### Moltbook

1. Visit https://moltbook.com/settings/api
2. Generate API key
3. Save to `~/.openclaw/workspace/.config/moltbook/credentials.json`

---

## Migration from Old Setup

If you had credentials in the old container that got lost:

1. Check if you have backups:

   ```bash
   ls -la ~/.openclaw/workspace/skills/notion/
   ```

2. Extract from browser:
   - Notion: https://www.notion.so/my-integrations
   - Twitter: Browser DevTools → Application → Cookies

3. Re-run OAuth flows on host if needed

---

## Questions?

- Check `./scripts/check-credentials.sh` for current status
- See individual skill READMEs in `~/.openclaw/workspace/skills/<skill>/SKILL.md`
- Ask in Discord: https://discord.gg/clawd
