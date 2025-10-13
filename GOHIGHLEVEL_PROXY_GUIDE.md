# GoHighLevel Proxy Server Guide

## 📋 Overview

The GoHighLevel proxy server is required for the **Advertisement Performance** page to work in the MedWave web app. It handles API requests to GoHighLevel CRM and bypasses CORS restrictions.

---

## 🚀 Quick Start Commands

### 1. **Start the Proxy Server**
```bash
./start-ghl-proxy.sh
```
This will:
- Check if Node.js is installed
- Install dependencies if needed
- Start the proxy on `http://localhost:3001`
- Show real-time logs

### 2. **Check Proxy Status**
```bash
./check-ghl-proxy.sh
```
This will tell you if the proxy is running or not.

### 3. **Stop the Proxy Server**
```bash
./stop-ghl-proxy.sh
```
This will gracefully stop the proxy server.

---

## 📝 Step-by-Step Instructions

### **Before Running Flutter App:**

1. **Open Terminal** and navigate to the project:
   ```bash
   cd /Users/mac/dev/medwave
   ```

2. **Start the proxy:**
   ```bash
   ./start-ghl-proxy.sh
   ```

3. **Wait for confirmation message:**
   ```
   🚀 GoHighLevel Proxy Server running on port 3001
   ```

4. **Now run your Flutter app:**
   ```bash
   flutter run -d chrome
   ```

5. **Navigate to:** Admin → Advertisement Performance

---

## 🔧 Manual Commands (Alternative)

If the scripts don't work, use these manual commands:

### Start Proxy:
```bash
cd ghl-proxy && npm start
```

### Check if Running:
```bash
curl http://localhost:3001/health
```

### Stop Proxy (find and kill process):
```bash
lsof -ti:3001 | xargs kill
```

---

## ⚠️ Troubleshooting

### **Problem: "Proxy server is NOT running"**
**Solution:** Run `./start-ghl-proxy.sh`

### **Problem: "Port 3001 is already in use"**
**Solution:** 
1. Stop the existing proxy: `./stop-ghl-proxy.sh`
2. Start again: `./start-ghl-proxy.sh`

### **Problem: "Node.js is not installed"**
**Solution:** Install Node.js from https://nodejs.org/ (LTS version recommended)

### **Problem: Flutter app shows CORS error**
**Solution:** 
1. Make sure proxy is running: `./check-ghl-proxy.sh`
2. Restart proxy: `./stop-ghl-proxy.sh && ./start-ghl-proxy.sh`
3. Hot reload Flutter app (press `r`)

### **Problem: "Failed to fetch pipelines"**
**Solution:**
1. Check proxy status: `./check-ghl-proxy.sh`
2. Check proxy logs in terminal for errors
3. Verify API key is correct in `ghl-proxy/server.js` (line 24)

---

## 📊 What the Proxy Does

The proxy server:
- ✅ Handles authentication with GoHighLevel API
- ✅ Bypasses browser CORS restrictions
- ✅ Fetches pipelines, opportunities, and campaign data
- ✅ Aggregates data into campaign and ad-level analytics
- ✅ Auto-refreshes data every 5 minutes in Flutter app

---

## 🌐 Production Deployment

**For production use, deploy the proxy to a cloud server:**

### Option 1: Heroku (Free Tier)
```bash
cd ghl-proxy
heroku create medwave-ghl-proxy
git push heroku main
```

### Option 2: AWS EC2 / Google Cloud / DigitalOcean
- Upload `ghl-proxy` folder to server
- Run `npm install` and `npm start`
- Use PM2 for process management: `pm2 start server.js --name ghl-proxy`

### Option 3: Vercel / Netlify (Serverless)
- Convert to serverless function
- Deploy `ghl-proxy` folder

**After deployment:**
Update `lib/config/api_keys.dart`:
```dart
static const String goHighLevelProxyUrl = 'https://your-proxy-domain.com/api/ghl';
```

---

## 📱 Client Demo Checklist

Before showing to client:

- [ ] Start proxy: `./start-ghl-proxy.sh`
- [ ] Verify proxy is running: `./check-ghl-proxy.sh`
- [ ] Start Flutter app: `flutter run -d chrome`
- [ ] Navigate to: Admin → Advertisement Performance
- [ ] Verify data loads (campaigns, ads, charts)
- [ ] Test refresh button
- [ ] Show campaign expansion (click to see individual ads)
- [ ] Show real-time metrics (leads, meetings, sales)

---

## 🔐 Security Notes

- API key is stored in `ghl-proxy/server.js`
- For production, use environment variables:
  ```bash
  export GHL_API_KEY=your-api-key
  ```
- Never commit API keys to Git (use `.env` file)
- The proxy should only be accessible by your Flutter app (CORS configured)

---

## 📞 Support

If issues persist:
1. Check proxy logs in terminal
2. Test API directly: `curl http://localhost:3001/api/ghl/pipelines`
3. Verify GoHighLevel API key has correct permissions
4. Check network connectivity

---

## 🎉 Success Indicators

When everything is working:
- ✅ Proxy shows: `🚀 GoHighLevel Proxy Server running on port 3001`
- ✅ Flutter app loads campaign data
- ✅ Charts display real data
- ✅ Expandable campaign cards show individual ads
- ✅ No CORS errors in console

