# GoHighLevel Proxy Server

This proxy server enables the MedWave Flutter web application to communicate with the GoHighLevel API by bypassing CORS restrictions.

## Setup

1. **Install Dependencies**
   ```bash
   cd ghl-proxy
   npm install
   ```

2. **Environment Configuration**
   ```bash
   cp .env.example .env
   # Edit .env with your specific configuration if needed
   ```

3. **Run Development Server**
   ```bash
   npm run dev
   ```

4. **Run Production Server**
   ```bash
   npm start
   ```

## Endpoints

- **Health Check**: `GET /health`
- **Pipelines**: `GET /api/ghl/pipelines`
- **Contacts**: `GET /api/ghl/contacts`
- **Opportunities**: `GET /api/ghl/opportunities`
- **Generic Proxy**: `ALL /api/ghl/*` (forwards to GoHighLevel API)

## Deployment

### Option 1: Heroku
```bash
# Install Heroku CLI, then:
heroku create your-ghl-proxy
heroku config:set GHL_API_KEY=your_api_key_here
git add .
git commit -m "Add GoHighLevel proxy server"
git push heroku main
```

### Option 2: Vercel
```bash
# Install Vercel CLI, then:
vercel
# Follow the prompts and set environment variables in Vercel dashboard
```

### Option 3: Railway
```bash
# Connect your GitHub repo to Railway and deploy
# Set environment variables in Railway dashboard
```

## CORS Configuration

The server is configured to allow requests from:
- `http://localhost:3000` (Flutter web dev)
- `http://localhost:8080` (Flutter web dev)
- `http://localhost:5000` (Flutter web dev)
- Your production domain (update in server.js)

## Security Notes

- API key is stored as environment variable
- CORS is configured for specific origins only
- All requests are logged for monitoring
- Error handling prevents API key exposure
