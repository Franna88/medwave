#!/bin/bash

# GoHighLevel Proxy Server Status Check Script
# This script checks if the proxy server is running

echo "🔍 Checking GoHighLevel Proxy Server status..."
echo ""

if curl -s http://localhost:3001/health > /dev/null 2>&1; then
    echo "✅ Proxy server is RUNNING on http://localhost:3001"
    echo ""
    
    # Get health check info
    HEALTH=$(curl -s http://localhost:3001/health)
    echo "📊 Server Info:"
    echo "$HEALTH" | jq '.' 2>/dev/null || echo "$HEALTH"
    
    exit 0
else
    echo "❌ Proxy server is NOT running"
    echo ""
    echo "To start the server, run: ./start-ghl-proxy.sh"
    exit 1
fi

