#!/bin/bash
# OpenClaw Web UI Launcher

GATEWAY_URL="http://127.0.0.1:18789"
TOKEN="da368509b19e077f0fd6607b79aca47a360862ad9c7bf9e5"

echo "================================"
echo "  OpenClaw Web UI"
echo "================================"
echo ""

# Check if Gateway is running
if ! curl -s -o /dev/null "${GATEWAY_URL}/"; then
    echo "❌ Gateway is not responding"
    echo "   Run: docker compose up -d openclaw-gateway"
    exit 1
fi

echo "✅ Gateway is running"
echo ""
echo "Opening Web UI..."
echo ""

# Open browser based on OS
UI_URL="${GATEWAY_URL}/overview?t=${TOKEN}"

case "$OSTYPE" in
    darwin*)
        open "$UI_URL"
        echo "🌐 Opened in browser: $UI_URL"
        ;;
    linux*)
        if command -v xdg-open &> /dev/null; then
            xdg-open "$UI_URL"
            echo "🌐 Opened in browser: $UI_URL"
        else
            echo "📎 Copy this URL to your browser:"
            echo "   $UI_URL"
        fi
        ;;
    msys*|cygwin*)
        start "$UI_URL"
        echo "🌐 Opened in browser: $UI_URL"
        ;;
    *)
        echo "📎 Copy this URL to your browser:"
        echo "   $UI_URL"
        ;;
esac

echo ""
echo "If the UI shows 'token missing':"
echo "  1. Click Settings (gear icon)"
echo "  2. Paste token: ${TOKEN:0:20}..."
