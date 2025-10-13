const express = require('express');
const cors = require('cors');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// CORS configuration - Allow all localhost origins for development
app.use(cors({
  origin: function(origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    // Allow all localhost origins (for Flutter web development)
    if (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) {
      return callback(null, true);
    }
    
    // Allow your production domain
    if (origin === 'https://your-medwave-domain.com') {
      return callback(null, true);
    }
    
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true
}));

app.use(express.json());

// GoHighLevel API configuration - Private Integration Token (API v2.0)
const GHL_BASE_URL = 'https://services.leadconnectorhq.com';
const GHL_API_KEY = process.env.GHL_API_KEY || 'pit-009fb0b0-1799-4773-82d2-a58cefcd9c6a';

// Default headers for GoHighLevel API (Private Integration Token)
const getGHLHeaders = () => ({
  'Authorization': `Bearer ${GHL_API_KEY}`,
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'User-Agent': 'MedWave-Integration/1.0',
  'Version': '2021-07-28'
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'GoHighLevel Proxy Server is running',
    timestamp: new Date().toISOString()
  });
});

// Debug endpoint to test authentication
app.get('/debug/auth', async (req, res) => {
  try {
    console.log('🔍 Testing GoHighLevel authentication...');
    console.log('🔑 Using API key:', GHL_API_KEY.substring(0, 20) + '...');
    console.log('🌐 Base URL:', GHL_BASE_URL);
    
    // Try different endpoints for API v2 with location ID
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    const endpoints = [
      `/locations/${locationId}`,
      `/locations/${locationId}/pipelines`,
      `/locations/${locationId}/contacts`,
      `/locations/${locationId}/opportunities`,
      '/locations',
      '/pipelines'
    ];
    
    let lastError = null;
    
    for (const endpoint of endpoints) {
      try {
        console.log(`🔍 Trying endpoint: ${endpoint}`);
        const response = await axios.get(`${GHL_BASE_URL}${endpoint}`, {
          headers: getGHLHeaders(),
          params: { limit: 1 }
        });
        
        console.log(`✅ Success with ${endpoint}:`, response.status);
        return res.json({
          status: 'success',
          message: `Authentication working with ${endpoint}`,
          endpoint: endpoint,
          responseStatus: response.status,
          dataKeys: Object.keys(response.data || {}),
          sampleData: response.data
        });
        
      } catch (error) {
        console.log(`❌ Failed ${endpoint}:`, error.response?.status, error.response?.data?.message || error.message);
        lastError = error;
        continue;
      }
    }
    
    // If we get here, all endpoints failed
    throw lastError;
    
  } catch (error) {
    console.error('❌ All auth tests failed:', error.message);
    console.error('❌ Status:', error.response?.status);
    console.error('❌ Headers sent:', getGHLHeaders());
    console.error('❌ Response data:', error.response?.data);
    
    res.status(500).json({
      status: 'error',
      message: error.message,
      responseStatus: error.response?.status,
      responseData: error.response?.data
    });
  }
});

// Proxy endpoint for GoHighLevel API
// Get all locations accessible to this token
app.get('/api/ghl/locations', async (req, res) => {
  try {
    console.log('🏢 Fetching all locations from GoHighLevel...');
    
    const response = await axios.get(`${GHL_BASE_URL}/locations/`, {
      headers: getGHLHeaders(),
      params: req.query
    });
    
    console.log(`✅ Retrieved ${response.data.locations?.length || 0} locations`);
    
    // Filter for MedWave SA specifically
    const medwaveSA = response.data.locations?.find(loc => 
      loc.name.includes('(SA)') || 
      loc.city === 'Jeffreys Bay' ||
      loc.state === 'Eastern Cape'
    );
    
    if (medwaveSA) {
      console.log(`🎯 Found MedWave SA location: ${medwaveSA.name} (${medwaveSA.id})`);
    }
    
    res.json({
      ...response.data,
      medwaveSA: medwaveSA
    });
    
  } catch (error) {
    console.error('❌ Error fetching locations:', error.message);
    res.status(error.response?.status || 500).json({
      error: error.response?.data || error.message
    });
  }
});

// Specific endpoints for GoHighLevel API (with location ID)
app.get('/api/ghl/pipelines', async (req, res) => {
  try {
    console.log('📊 Fetching pipelines from GoHighLevel...');
    
    // Use the known MedWave SA location ID directly
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    
    console.log(`🎯 Using MedWave SA location ID: ${locationId}`);
    
    // Use the working endpoint pattern with locationId as query parameter
    const response = await axios.get(`${GHL_BASE_URL}/opportunities/pipelines`, {
      headers: getGHLHeaders(),
      params: {
        locationId: locationId,
        ...req.query
      }
    });
    
    console.log(`✅ Retrieved ${response.data.pipelines?.length || 0} pipelines`);
    
    // Find the Erich Pipeline specifically
    const erichPipeline = response.data.pipelines?.find(p => p.name.includes('Erich'));
    if (erichPipeline) {
      console.log(`🎯 Found Erich Pipeline: ${erichPipeline.name} (${erichPipeline.id})`);
    }
    
    res.json({
      ...response.data,
      locationUsed: { id: locationId, name: 'MedWave™ (SA)' },
      erichPipeline: erichPipeline
    });
    
  } catch (error) {
    console.error('❌ Error fetching pipelines:', error.message);
    console.error('❌ Response status:', error.response?.status);
    console.error('❌ Response data:', error.response?.data);
    res.status(error.response?.status || 500).json({
      error: error.response?.data || error.message,
      status: error.response?.status
    });
  }
});

app.get('/api/ghl/contacts', async (req, res) => {
  try {
    console.log('👥 Fetching contacts from GoHighLevel...');
    
    // Use the known MedWave SA location ID directly
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    
    console.log(`🎯 Using MedWave SA location ID: ${locationId}`);
    
    // Use the working endpoint pattern with locationId as query parameter
    const response = await axios.get(`${GHL_BASE_URL}/contacts/`, {
      headers: getGHLHeaders(),
      params: {
        locationId: locationId,
        limit: req.query.limit || 100,
        ...req.query
      }
    });
    
    console.log(`✅ Retrieved ${response.data.contacts?.length || 0} contacts (Total: ${response.data.meta?.total || 0})`);
    
    res.json({
      ...response.data,
      locationUsed: { id: locationId, name: 'MedWave™ (SA)' }
    });
    
  } catch (error) {
    console.error('❌ Error fetching contacts:', error.message);
    res.status(error.response?.status || 500).json({
      error: error.response?.data || error.message
    });
  }
});

app.get('/api/ghl/opportunities', async (req, res) => {
  try {
    console.log('💼 Fetching opportunities from GoHighLevel...');
    
    // Use the known MedWave SA location ID directly
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    
    console.log(`🎯 Using MedWave SA location ID: ${locationId}`);
    
    // Try the opportunities search endpoint (this is typically used for querying opportunities)
    const response = await axios.get(`${GHL_BASE_URL}/opportunities/search`, {
      headers: getGHLHeaders(),
      params: {
        location_id: locationId,
        limit: req.query.limit || 100,
        ...req.query
      }
    });
    
    console.log(`✅ Retrieved ${response.data.opportunities?.length || 0} opportunities`);
    
    res.json({
      ...response.data,
      locationUsed: { id: locationId, name: 'MedWave™ (SA)' }
    });
    
  } catch (error) {
    console.error('❌ Error fetching opportunities:', error.message);
    console.error('❌ Response status:', error.response?.status);
    console.error('❌ Response data:', error.response?.data);
    res.status(error.response?.status || 500).json({
      error: error.response?.data || error.message
    });
  }
});

// Campaign Performance Analytics Endpoint
app.get('/api/ghl/analytics/campaign-performance', async (req, res) => {
  try {
    console.log('📊 Calculating campaign performance analytics...');
    
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    const erichPipelineId = 'pTbNvnrXqJc9u1oxir3q';
    
    // Fetch opportunities from Erich Pipeline
    // Note: For now fetching first 100, can implement cursor pagination later
    const response = await axios.get(`${GHL_BASE_URL}/opportunities/search`, {
      headers: getGHLHeaders(),
      params: {
        location_id: locationId,
        limit: 100,
        pipeline_id: erichPipelineId
      }
    });
    
    const erichOpportunities = response.data.opportunities || [];
    
    console.log(`✅ Total Erich Pipeline opportunities fetched: ${erichOpportunities.length}`);
    
    // Define Erich Pipeline stage mappings
    const stageMapping = {
      // High Quality Lead stages
      hqlStages: [
        'a7dc3005-499b-4faa-aac1-a52893481661', // (E) High Quality (Contacted)
        'bc306cb3-3254-4179-b38c-5e91d77f6435', // (E) High Quality (Responded)
        '155055b0-6631-4ab8-9ecd-7d9ccdb903c2', // (E) High Quality (Qualified)
        'db96a1ec-e8b9-4c86-8d2d-065528ccf7e4'  // (E) High Interest Follow-Up
      ],
      // Appointment stages
      appointmentStages: [
        'b28f4789-ef6b-45ff-955a-fec85530ece5', // (E) Andries Booked
        '10c26bf0-72ac-4e17-87d5-3056f1de7e2d', // (E) Altus Booked
        'bc9ad460-944c-440c-87e9-359676218684'  // (E) Margo Booked
      ],
      // Reschedule/No Show stages
      rescheduleStages: [
        '149f0364-dad3-47f3-9f8c-bf05efa01cff', // (E) Andries Reschedule
        'ed1ec4cb-98ff-449b-bff4-809c00dc7997'  // (E) Altus Reschedule
      ],
      // Sale stages
      saleStages: [
        '496d99ad-672b-4551-9b9e-d81679c4735f', // Ruwayne Purchased
        'e55fa00e-5461-4914-9cbe-6f76d8b66c56'  // NEW NEURO PORTABLE
      ],
      // Lost stage
      lostStage: 'c0b4eadc-cead-40ce-9567-b96a5eaddb5b' // (E) Lost
    };
    
    // Group by campaign AND by ad (within campaign)
    const campaignStats = {};
    const adStats = {}; // Track individual ads
    
    erichOpportunities.forEach(opp => {
      // Get campaign and ad info from attributions
      const lastAttribution = opp.attributions?.find(attr => attr.isLast) || opp.attributions?.[0];
      const campaignId = lastAttribution?.utmCampaignId || 'unknown';
      const campaignName = lastAttribution?.utmCampaign || 'Unknown Campaign';
      const adSource = lastAttribution?.adSource || lastAttribution?.utmSource || 'unknown';
      const utmMedium = lastAttribution?.utmMedium || '';
      const adId = lastAttribution?.utmAdId || lastAttribution?.utmContent || 'unknown-ad';
      const adName = lastAttribution?.utmContent || 'Unnamed Ad';
      
      // Initialize campaign stats if not exists
      if (!campaignStats[campaignId]) {
        campaignStats[campaignId] = {
          campaignId,
          campaignName,
          adSource,
          utmMedium,
          totalLeads: 0,
          hqlLeads: 0,
          aveLeads: 0,
          salesAgents: {},
          appointments: { booked: 0, noAppointment: 0, rescheduled: 0 },
          showStatus: { optIn: 0, noShow: 0 },
          sales: { sold: 0, notSold: 0, pending: 0 },
          deposits: 0,
          installations: 0,
          cashCollected: 0,
          monetaryValue: 0,
          ads: {} // Track ads within this campaign
        };
      }
      
      // Initialize ad stats if not exists (unique key: campaignId + adId)
      const adKey = `${campaignId}_${adId}`;
      if (!adStats[adKey]) {
        adStats[adKey] = {
          adId,
          adName,
          campaignId,
          campaignName,
          totalLeads: 0,
          hqlLeads: 0,
          aveLeads: 0,
          salesAgents: {},
          appointments: { booked: 0, noAppointment: 0, rescheduled: 0 },
          showStatus: { optIn: 0, noShow: 0 },
          sales: { sold: 0, notSold: 0, pending: 0 },
          deposits: 0,
          installations: 0,
          cashCollected: 0,
          monetaryValue: 0
        };
        // Also add to campaign's ads object
        campaignStats[campaignId].ads[adId] = adStats[adKey];
      }
      
      const stats = campaignStats[campaignId];
      const adStat = adStats[adKey];
      
      stats.totalLeads++;
      adStat.totalLeads++;
      
      const stageId = opp.pipelineStageId;
      
      // Classify as HQL or Ave Lead based on pipeline stage (for both campaign and ad)
      if (stageMapping.hqlStages.includes(stageId)) {
        stats.hqlLeads++;
        adStat.hqlLeads++;
      } else {
        stats.aveLeads++;
        adStat.aveLeads++;
      }
      
      // Track sales agent (for both campaign and ad)
      if (opp.assignedTo) {
        // Campaign level
        if (!stats.salesAgents[opp.assignedTo]) {
          stats.salesAgents[opp.assignedTo] = {
            agentId: opp.assignedTo,
            leadCount: 0,
            appointments: 0,
            sales: 0
          };
        }
        stats.salesAgents[opp.assignedTo].leadCount++;
        
        // Ad level
        if (!adStat.salesAgents[opp.assignedTo]) {
          adStat.salesAgents[opp.assignedTo] = {
            agentId: opp.assignedTo,
            leadCount: 0,
            appointments: 0,
            sales: 0
          };
        }
        adStat.salesAgents[opp.assignedTo].leadCount++;
      }
      
      // Check for appointments based on pipeline stage (for both campaign and ad)
      if (stageMapping.appointmentStages.includes(stageId)) {
        stats.appointments.booked++;
        adStat.appointments.booked++;
        if (opp.assignedTo) {
          if (stats.salesAgents[opp.assignedTo]) {
            stats.salesAgents[opp.assignedTo].appointments++;
          }
          if (adStat.salesAgents[opp.assignedTo]) {
            adStat.salesAgents[opp.assignedTo].appointments++;
          }
        }
      } else if (stageMapping.rescheduleStages.includes(stageId)) {
        stats.appointments.rescheduled++;
        adStat.appointments.rescheduled++;
      } else {
        stats.appointments.noAppointment++;
        adStat.appointments.noAppointment++;
      }
      
      // Check for show status (for both campaign and ad)
      const appointmentStageIndex = stageMapping.appointmentStages.indexOf(stageId);
      if (appointmentStageIndex >= 0) {
        if (!stageMapping.rescheduleStages.includes(stageId)) {
          stats.showStatus.optIn++;
          adStat.showStatus.optIn++;
        } else {
          stats.showStatus.noShow++;
          adStat.showStatus.noShow++;
        }
      }
      
      // Check for sales based on pipeline stage (for both campaign and ad)
      if (stageMapping.saleStages.includes(stageId)) {
        stats.sales.sold++;
        adStat.sales.sold++;
        if (opp.assignedTo) {
          if (stats.salesAgents[opp.assignedTo]) {
            stats.salesAgents[opp.assignedTo].sales++;
          }
          if (adStat.salesAgents[opp.assignedTo]) {
            adStat.salesAgents[opp.assignedTo].sales++;
          }
        }
      } else if (stageId === stageMapping.lostStage || opp.status === 'lost') {
        stats.sales.notSold++;
        adStat.sales.notSold++;
      } else {
        stats.sales.pending++;
        adStat.sales.pending++;
      }
      
      // Add monetary value (for both campaign and ad)
      stats.monetaryValue += opp.monetaryValue || 0;
      adStat.monetaryValue += opp.monetaryValue || 0;
      
      // Track deposits and cash collected (for both campaign and ad)
      if (opp.monetaryValue > 0) {
        stats.deposits++;
        adStat.deposits++;
        if (stageMapping.saleStages.includes(stageId)) {
          stats.cashCollected += opp.monetaryValue;
          adStat.cashCollected += opp.monetaryValue;
          stats.installations++;
          adStat.installations++;
        }
      }
    });
    
    // Helper function to calculate conversion rates
    const calculateConversionRates = (data) => ({
      hqlRate: data.totalLeads > 0 ? (data.hqlLeads / data.totalLeads * 100).toFixed(2) : 0,
      appointmentRate: data.totalLeads > 0 ? (data.appointments.booked / data.totalLeads * 100).toFixed(2) : 0,
      showRate: data.appointments.booked > 0 ? (data.showStatus.optIn / data.appointments.booked * 100).toFixed(2) : 0,
      saleRate: data.totalLeads > 0 ? (data.sales.sold / data.totalLeads * 100).toFixed(2) : 0,
      depositRate: data.totalLeads > 0 ? (data.deposits / data.totalLeads * 100).toFixed(2) : 0
    });
    
    // Convert to array and calculate conversion rates for campaigns
    const campaigns = Object.values(campaignStats).map(campaign => {
      // Convert ads object to array with conversion rates
      const adsArray = Object.values(campaign.ads).map(ad => ({
        ...ad,
        conversionRates: calculateConversionRates(ad),
        salesAgentsList: Object.values(ad.salesAgents),
        salesAgents: undefined
      }));
      
      // Sort ads by total leads descending
      adsArray.sort((a, b) => b.totalLeads - a.totalLeads);
      
      return {
        ...campaign,
        conversionRates: calculateConversionRates(campaign),
        salesAgentsList: Object.values(campaign.salesAgents),
        ads: adsArray, // Replace ads object with sorted array
        salesAgents: undefined, // Remove the salesAgents object to avoid duplication
        totalAds: adsArray.length
      };
    });
    
    // Sort by total leads descending
    campaigns.sort((a, b) => b.totalLeads - a.totalLeads);
    
    // Create a flat array of all ads for easier access
    const allAds = campaigns.flatMap(campaign => 
      campaign.ads.map(ad => ({
        ...ad,
        campaignName: campaign.campaignName // Include campaign name for context
      }))
    );
    
    // Sort all ads by total leads
    allAds.sort((a, b) => b.totalLeads - a.totalLeads);
    
    res.json({
      summary: {
        totalCampaigns: campaigns.length,
        totalAds: allAds.length,
        totalLeads: erichOpportunities.length,
        totalHQL: campaigns.reduce((sum, c) => sum + c.hqlLeads, 0),
        totalAve: campaigns.reduce((sum, c) => sum + c.aveLeads, 0),
        totalAppointments: campaigns.reduce((sum, c) => sum + c.appointments.booked, 0),
        totalSales: campaigns.reduce((sum, c) => sum + c.sales.sold, 0),
        totalRevenue: campaigns.reduce((sum, c) => sum + c.cashCollected, 0)
      },
      campaigns, // Campaigns with nested ads
      allAds, // Flat array of all ads across all campaigns
      locationUsed: { id: locationId, name: 'MedWave™ (SA)' },
      pipelineUsed: { id: erichPipelineId, name: 'Erich Pipeline -DDM' }
    });
    
  } catch (error) {
    console.error('❌ Error calculating campaign performance:', error.message);
    console.error('❌ Response status:', error.response?.status);
    console.error('❌ Response data:', error.response?.data);
    res.status(error.response?.status || 500).json({
      error: error.response?.data || error.message,
      message: 'Failed to calculate campaign performance'
    });
  }
});

// Generic catch-all proxy route (MUST be last to not interfere with specific routes)
app.all('/api/ghl/*', async (req, res) => {
  try {
    // Extract the path after /api/ghl/
    const ghlPath = req.path.replace('/api/ghl', '');
    const ghlUrl = `${GHL_BASE_URL}${ghlPath}`;
    
    console.log(`📡 Proxying ${req.method} request to: ${ghlUrl}`);
    
    // Prepare the request configuration
    const config = {
      method: req.method.toLowerCase(),
      url: ghlUrl,
      headers: getGHLHeaders(),
      params: req.query,
    };
    
    // Add request body for POST/PUT requests
    if (['post', 'put', 'patch'].includes(config.method)) {
      config.data = req.body;
    }
    
    // Make the request to GoHighLevel API
    const response = await axios(config);
    
    console.log(`✅ GoHighLevel API response: ${response.status}`);
    
    // Forward the response back to the Flutter app
    res.status(response.status).json(response.data);
    
  } catch (error) {
    console.error('❌ GoHighLevel API Error:', error.message);
    
    if (error.response) {
      // API returned an error response
      res.status(error.response.status).json({
        error: error.response.data,
        message: `GoHighLevel API Error: ${error.response.status}`
      });
    } else if (error.request) {
      // Request was made but no response received
      res.status(503).json({
        error: 'Service Unavailable',
        message: 'Unable to reach GoHighLevel API'
      });
    } else {
      // Something else happened
      res.status(500).json({
        error: 'Internal Server Error',
        message: error.message
      });
    }
  }
});

// Start the server
app.listen(PORT, () => {
  console.log(`🚀 GoHighLevel Proxy Server running on port ${PORT}`);
  console.log(`📡 Proxying requests to: ${GHL_BASE_URL}`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
  console.log(`🌐 CORS enabled for Flutter web app`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('👋 GoHighLevel Proxy Server shutting down...');
  process.exit(0);
});
