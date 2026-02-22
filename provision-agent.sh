#!/bin/bash
# provision-agent.sh - Automatically provision a new WeAgents agent
# Usage: ./provision-agent.sh <agent-name> [port]

set -e

WEAGENTS_DIR="/opt/weagents"
AGENT_NAME="${1:-weagent-001}"
AGENT_PORT="${2:-8080}"
AGENT_ID="$(date +%s)"

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }

if [ "$EUID" -ne 0 ]; then
echo "Please run as root (use sudo)"
exit 1
fi

if [ -d "$WEAGENTS_DIR/agents/$AGENT_NAME" ]; then
log_warn "Agent $AGENT_NAME already exists!"
read -p "Overwrite? (y/N): " confirm
[[ $confirm =~ ^[Yy]$ ]] || exit 0
rm -rf "$WEAGENTS_DIR/agents/$AGENT_NAME"
fi

log_info "Provisioning agent: $AGENT_NAME on port $AGENT_PORT"

# Create directories
mkdir -p "$WEAGENTS_DIR/agents/$AGENT_NAME"/{workspace/memory,data,.config}
mkdir -p "$WEAGENTS_DIR/configs" "$WEAGENTS_DIR/logs"

# Create env file
cat > "$WEAGENTS_DIR/configs/$AGENT_NAME.env" << EOF
OPENCLAW_AGENT_NAME=$AGENT_NAME
OPENCLAW_AGENT_ID=$AGENT_ID
OPENCLAW_WORKSPACE=/app/workspace
OPENCLAW_DEFAULT_MODEL=kimi-coding/kimi-for-coding
OPENCLAW_ENABLE_REASONING=false
TZ=Asia/Singapore
EOF

# Create SOUL.md
cat > "$WEAGENTS_DIR/agents/$AGENT_NAME/workspace/SOUL.md" << 'EOF'
# SOUL.md - Who You Are
**Name:** Kai
**Vibe:** Helpful, competent, straightforward — no fluff.
EOF

# Create IDENTITY.md
cat > "$WEAGENTS_DIR/agents/$AGENT_NAME/workspace/IDENTITY.md" << EOF
# IDENTITY.md
- **Name:** Kai
- **Agent ID:** $AGENT_ID
- **Created:** $(date +%Y-%m-%d)
EOF

# Create other minimal files
echo "# USER.md - About Your Human" > "$WEAGENTS_DIR/agents/$AGENT_NAME/workspace/USER.md"
echo "# TOOLS.md - Credentials" > "$WEAGENTS_DIR/agents/$AGENT_NAME/workspace/TOOLS.md"
echo "# MEMORY.md" > "$WEAGENTS_DIR/agents/$AGENT_NAME/workspace/MEMORY.md"
echo "# HEARTBEAT.md" > "$WEAGENTS_DIR/agents/$AGENT_NAME/workspace/HEARTBEAT.md"
echo "# TODO.md" > "$WEAGENTS_DIR/agents/$AGENT_NAME/workspace/TODO.md"

# Set permissions
chown -R 1000:1000 "$WEAGENTS_DIR/agents/$AGENT_NAME/workspace"
chown -R 1000:1000 "$WEAGENTS_DIR/agents/$AGENT_NAME/data"
chmod -R 755 "$WEAGENTS_DIR/agents/$AGENT_NAME/workspace"

# Create or update docker-compose.yml
if [ ! -f "$WEAGENTS_DIR/docker-compose.yml" ]; then
cat > "$WEAGENTS_DIR/docker-compose.yml" << 'EOF'
version: '3.8'
networks:
weagents:
driver: bridge
EOF
fi

# Append service
cat >> "$WEAGENTS_DIR/docker-compose.yml" << EOF

$AGENT_NAME:
image: openclaw:latest
container_name: $AGENT_NAME
restart: unless-stopped
env_file:
- ./configs/$AGENT_NAME.env
environment:
- OPENCLAW_AGENT_NAME=$AGENT_NAME
- OPENCLAW_AGENT_ID=$AGENT_ID
- TZ=Asia/Singapore
volumes:
- ./agents/$AGENT_NAME/workspace:/app/workspace:rw
- ./agents/$AGENT_NAME/data:/app/data:rw
- ./agents/$AGENT_NAME/.config:/root/.config:rw
ports:
- "$AGENT_PORT:8080"
networks:
- weagents
deploy:
resources:
limits:
cpus: '0.5'
memory: 512M
EOF

log_info "Agent $AGENT_NAME provisioned successfully!"
log_info "Start with: cd $WEAGENTS_DIR && docker compose up -d $AGENT_NAME"
