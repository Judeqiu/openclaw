#!/bin/bash
# Check credential status for OpenClaw Docker

echo "=============================================="
echo "  OpenClaw Credential Status Check"
echo "=============================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $2: $1"
        return 0
    else
        echo -e "${RED}✗${NC} $2: Not found at $1"
        return 1
    fi
}

check_env() {
    if [ -n "${!1}" ]; then
        echo -e "${GREEN}✓${NC} $2: Set"
        return 0
    else
        echo -e "${RED}✗${NC} $2: Not set"
        return 1
    fi
}

check_docker_env() {
    local val=$(docker compose exec openclaw-gateway printenv "$1" 2>/dev/null | tr -d '\r')
    if [ -n "$val" ]; then
        echo -e "${GREEN}✓${NC} $2: Available in container"
        return 0
    else
        echo -e "${RED}✗${NC} $2: Not available in container"
        return 1
    fi
}

echo "=== HOST CREDENTIALS ==="
echo ""

# File-based credentials
check_file "$HOME/.config/notion/token.txt" "Notion Token"
check_file "$HOME/.openclaw/workspace/.config/moltbook/credentials.json" "Moltbook Credentials"
check_file "$HOME/.openclaw/workspace/skills/calendar-intelligence/token.json" "Google Calendar Token"
check_file "$HOME/.aws/credentials" "AWS Credentials"
check_file "$HOME/.config/gcloud/application_default_credentials.json" "GCloud Credentials"

echo ""
echo "=== ENVIRONMENT VARIABLES (Host) ==="
echo ""

# Source credentials file if it exists
if [ -f ".env.credentials" ]; then
    export $(grep -v '^#' .env.credentials | xargs) 2>/dev/null
fi

check_env "BRAVE_API_KEY" "Brave Search API Key"
check_env "MEMORY_BOT_TOKEN" "Memory Bot Token"
check_env "GMAIL_APP_PASSWORD" "Gmail App Password"
check_env "TWITTER_AUTH_TOKEN" "Twitter Auth Token"
check_env "TWITTER_CT0" "Twitter CT0"
check_env "POLYMARKET_API_KEY" "Polymarket API Key"

echo ""
echo "=== CONTAINER CREDENTIALS ==="
echo ""

# Check if container is running
if docker compose ps | grep -q "openclaw-gateway"; then
    check_docker_env "NOTION_TOKEN" "Notion (via file mount)"
    check_docker_env "BRAVE_API_KEY" "Brave Search API Key"
    check_docker_env "MEMORY_BOT_TOKEN" "Memory Bot Token"
    check_docker_env "GMAIL_APP_PASSWORD" "Gmail App Password"
else
    echo -e "${YELLOW}⚠${NC} Gateway container not running - can't check container credentials"
fi

echo ""
echo "=== RECOMMENDATIONS ==="
echo ""

# Check for missing credentials
MISSING=0

if [ ! -f "$HOME/.config/notion/token.txt" ]; then
    MISSING=$((MISSING + 1))
    echo -e "${YELLOW}•${NC} Create Notion token:"
    echo "  1. Visit https://www.notion.so/my-integrations"
    echo "  2. Create integration and copy token"
    echo "  3. mkdir -p ~/.config/notion"
    echo "  4. echo 'secret_xxx' > ~/.config/notion/token.txt"
    echo ""
fi

if [ -z "$BRAVE_API_KEY" ]; then
    MISSING=$((MISSING + 1))
    echo -e "${YELLOW}•${NC} Set up Brave Search:"
    echo "  1. Visit https://api.search.brave.com/app/keys"
    echo "  2. Copy .env.credentials.example to .env.credentials"
    echo "  3. Add BRAVE_API_KEY=your_key to .env.credentials"
    echo ""
fi

if [ $MISSING -eq 0 ]; then
    echo -e "${GREEN}All credentials configured!${NC}"
fi

echo ""
echo "=============================================="
echo "For more info, see: docs/CREDENTIALS.md"
echo "=============================================="
