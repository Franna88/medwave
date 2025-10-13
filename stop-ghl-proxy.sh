#!/bin/bash

# GoHighLevel Proxy Server Stop Script
# This script stops the running proxy server

echo "🛑 Stopping GoHighLevel Proxy Server..."
echo ""

# Find and kill the process
PIDS=$(lsof -ti:3001)

if [ -z "$PIDS" ]; then
    echo "✅ No proxy server running on port 3001"
    exit 0
fi

echo "🔍 Found process(es): $PIDS"
kill $PIDS

# Wait a moment and check if it stopped
sleep 1

if lsof -ti:3001 > /dev/null 2>&1; then
    echo "⚠️  Process still running, forcing shutdown..."
    kill -9 $(lsof -ti:3001)
    sleep 1
fi

if lsof -ti:3001 > /dev/null 2>&1; then
    echo "❌ Failed to stop proxy server"
    exit 1
else
    echo "✅ Proxy server stopped successfully"
fi

