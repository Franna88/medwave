#!/bin/bash

echo "🚀 Setting up GoHighLevel Proxy Server for MedWave..."

# Navigate to proxy directory
cd ghl-proxy

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first:"
    echo "   https://nodejs.org/"
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm first."
    exit 1
fi

echo "📦 Installing dependencies..."
npm install

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "⚙️ Creating .env file..."
    cp .env.example .env
    echo "✅ Created .env file. You can edit it if needed."
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "🔧 To start the proxy server:"
echo "   cd ghl-proxy"
echo "   npm run dev"
echo ""
echo "🌐 The proxy will run on: http://localhost:3001"
echo "📊 Health check: http://localhost:3001/health"
echo ""
echo "🔗 Your Flutter web app will use this proxy to access GoHighLevel API"
