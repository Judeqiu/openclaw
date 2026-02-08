#!/bin/bash
# OpenClaw UI Access Helper

GATEWAY_URL="http://127.0.0.1:18789"
TOKEN="da368509b19e077f0fd6607b79aca47a360862ad9c7bf9e5"
TOKENIZED_URL="${GATEWAY_URL}/overview?t=${TOKEN}"

echo "================================"
echo "  OpenClaw Web UI Access"
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
echo "Tokenized URL (auto-authenticated):"
echo "   ${TOKENIZED_URL}"
echo ""

# Open browser
if [[ "$OSTYPE" == "darwin"* ]]; then
    open "$TOKENIZED_URL"
    echo "🌐 Opening browser..."
elif command -v xdg-open &> /dev/null; then
    xdg-open "$TOKENIZED_URL"
    echo "🌐 Opening browser..."
else
    echo "📎 Please open the URL manually"
fi

echo ""
echo "Note: If the UI shows 'Settings', the token is already applied."
echo "      You should see the OpenClaw dashboard with agent status."
