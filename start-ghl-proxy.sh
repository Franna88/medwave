#!/bin/bash

# GoHighLevel Proxy Server Startup Script
# This script starts the proxy server needed for GoHighLevel integration

echo "🚀 Starting GoHighLevel Proxy Server..."
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ ERROR: Node.js is not installed"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

# Navigate to proxy directory
cd "$(dirname "$0")/ghl-proxy" || {
    echo "❌ ERROR: ghl-proxy directory not found"
    exit 1
}

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Check if proxy is already running
if curl -s http://localhost:3001/health > /dev/null 2>&1; then
    echo "⚠️  Proxy server is already running on port 3001"
    echo ""
    echo "To restart, first run: ./stop-ghl-proxy.sh"
    exit 0
fi

# Start the proxy server
echo "🌐 Starting proxy on http://localhost:3001"
echo "📡 Press Ctrl+C to stop the server"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

npm start

