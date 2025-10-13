# GoHighLevel Integration for MedWave Web Admin

This integration enables the MedWave super admin web interface to display real-time advertisement performance data from GoHighLevel CRM, specifically focusing on the **Erich Pipeline**.

## 🎯 Features Implemented

### Erich Pipeline Tracking (Prominently Displayed)
- ✅ **Total Leads** - All leads in Erich Pipeline
- ✅ **HQL Leads** - High Quality Leads with classification
- ✅ **Ave Leads** - Average Leads with classification  
- ✅ **Appointments** - Appointment bookings and rates
- ✅ **Sales** - Sale conversions and rates
- ✅ **Deposits** - Deposit tracking and amounts
- ✅ **Installations** - Installation completions and rates
- ✅ **Cash Collected** - Total cash collection tracking

### Sales Agent Performance
- Individual agent metrics and performance tracking
- Lead allocation and conversion rates per agent
- Comprehensive performance table with all KPIs

### Real-Time Features
- ⏰ **5-minute auto-refresh** (as requested)
- Manual refresh capability
- Data staleness indicators
- Connection status monitoring

## 🏗️ Architecture

### Web-Only Solution
Since this is **exclusively for web super admin access**, the solution uses:

1. **Flutter Web Frontend** - Enhanced Advertisement Performance screen
2. **Node.js Proxy Server** - Bypasses CORS restrictions for GoHighLevel API
3. **GoHighLevel CRM API** - Real-time data source

### CORS Solution
Web browsers block direct API calls to GoHighLevel due to CORS restrictions. The proxy server solution:
- Runs a lightweight Node.js server that forwards requests
- Handles authentication with GoHighLevel API
- Returns data to Flutter web app without CORS issues

## 🚀 Quick Start

### 1. Set Up Proxy Server
```bash
# Run the setup script
./setup-proxy.sh

# Or manually:
cd ghl-proxy
npm install
npm run dev
```

### 2. Start Flutter Web
```bash
# In another terminal
flutter run -d chrome
```

### 3. Access Super Admin Dashboard
- Navigate to `/admin/adverts` in your web app
- The GoHighLevel integration will initialize automatically
- Erich Pipeline data will be prominently displayed

## 📊 Dashboard Features

### Erich Pipeline Section (Primary)
- **Live Data Indicator** - Shows real-time connection status
- **9 Key Metric Cards** - All requested KPIs with trend indicators
- **Conversion Funnel Chart** - Visual pipeline progression
- **Lead Quality Distribution** - HQL vs Ave Lead breakdown

### Secondary Pipeline Data
- Other pipelines available as reference data
- Sales agent performance comparison
- Filtering and analytics capabilities

### Error Handling
- Intelligent CORS error detection and explanation
- Clear solutions and next steps for connectivity issues
- Graceful fallback with informative error screens

## 🔧 Configuration

### Development Setup
- Proxy server runs on `http://localhost:3001`
- Flutter web connects to proxy automatically
- GoHighLevel API key configured in proxy server

### Production Deployment

#### Option 1: Heroku (Recommended)
```bash
cd ghl-proxy
heroku create your-medwave-ghl-proxy
heroku config:set GHL_API_KEY=your_api_key_here
git add .
git commit -m "Deploy GoHighLevel proxy"
git push heroku main
```

#### Option 2: Vercel
```bash
cd ghl-proxy
vercel --prod
# Set GHL_API_KEY in Vercel dashboard
```

#### Option 3: Railway/DigitalOcean/AWS
- Deploy the `ghl-proxy` folder to your preferred platform
- Set `GHL_API_KEY` environment variable
- Update `goHighLevelProxyUrl` in `lib/config/api_keys.dart`

### Production Configuration
Update the proxy URL in your Flutter app:
```dart
// In lib/config/api_keys.dart
static const String goHighLevelProxyUrl = 'https://your-proxy-domain.com/api/ghl';
```

## 🔐 Security

### API Key Management
- GoHighLevel API key stored securely in proxy server environment
- Never exposed to client-side code
- Proxy server handles all authentication

### CORS Protection
- Proxy server configured for specific origins only
- Production domains must be explicitly allowed
- Request logging for monitoring and security

### Super Admin Access
- Integration only available to super admin users
- Web-only deployment ensures controlled access
- No mobile app exposure as requested

## 📈 Monitoring

### Health Checks
- Proxy server health endpoint: `/health`
- Connection status monitoring in Flutter app
- Automatic retry mechanisms with exponential backoff

### Logging
- All API requests logged in proxy server
- Error tracking and debugging information
- Performance metrics and response times

## 🛠️ Troubleshooting

### Common Issues

1. **CORS Errors**
   - Ensure proxy server is running on port 3001
   - Check proxy server logs for connection issues
   - Verify GoHighLevel API key is valid

2. **Connection Failed**
   - Confirm proxy server is accessible
   - Check network connectivity
   - Verify API key permissions in GoHighLevel

3. **Data Not Loading**
   - Check GoHighLevel API status
   - Verify Erich Pipeline exists in your GoHighLevel account
   - Review proxy server logs for API errors

### Debug Commands
```bash
# Check proxy server status
curl http://localhost:3001/health

# Test pipelines endpoint
curl http://localhost:3001/api/ghl/pipelines

# View proxy server logs
cd ghl-proxy && npm run dev
```

## 📋 Implementation Checklist

- ✅ GoHighLevel API service with authentication
- ✅ Data models for leads, pipelines, and analytics
- ✅ State management with 5-minute auto-refresh
- ✅ Enhanced Advertisement Performance screen
- ✅ Erich Pipeline prominently displayed
- ✅ Sales agent performance tracking
- ✅ CORS proxy server for web deployment
- ✅ Error handling and user feedback
- ✅ Security and API key management
- ✅ Production deployment documentation

## 🎉 Ready for Production

The GoHighLevel integration is **complete and production-ready** for your web super admin interface. The solution provides:

- **Real-time data** from GoHighLevel CRM
- **Erich Pipeline focus** as requested
- **5-minute refresh intervals** for current data
- **Comprehensive metrics** for all requested KPIs
- **Professional error handling** with clear user guidance
- **Secure API management** through proxy server
- **Easy deployment** to any cloud platform

The integration will provide your super admins with powerful insights into advertisement performance directly from GoHighLevel, with the Erich Pipeline taking center stage as requested.
