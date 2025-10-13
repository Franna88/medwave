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

// Pipeline Performance Analytics Endpoint (Altus + Andries)
app.get('/api/ghl/analytics/pipeline-performance', async (req, res) => {
  try {
    console.log('📊 Calculating pipeline performance analytics for Altus and Andries...');
    
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    
    // Pipeline IDs for Altus and Andries
    const altusPipelineId = req.query.altusPipelineId || 'AUduOJBB2lxlsEaNmlJz'; // Altus Pipeline - DDM
    const andriesPipelineId = req.query.andriesPipelineId || 'XeAGJWRnUGJ5tuhXam2g'; // Andries Pipeline - DDM
    
    // First, fetch pipelines to get stage ID to name mapping
    const pipelinesResponse = await axios.get(`${GHL_BASE_URL}/opportunities/pipelines`, {
      headers: getGHLHeaders(),
      params: { locationId }
    });
    
    const pipelines = pipelinesResponse.data.pipelines || [];
    const altusPipeline = pipelines.find(p => p.id === altusPipelineId);
    const andriesPipeline = pipelines.find(p => p.id === andriesPipelineId);
    
    // Create stage ID to name mapping
    const stageIdToName = {};
    if (altusPipeline && altusPipeline.stages) {
      altusPipeline.stages.forEach(stage => {
        stageIdToName[stage.id] = stage.name;
      });
    }
    if (andriesPipeline && andriesPipeline.stages) {
      andriesPipeline.stages.forEach(stage => {
        stageIdToName[stage.id] = stage.name;
      });
    }
    
    console.log('📋 Stage ID to Name mapping created:', Object.keys(stageIdToName).length, 'stages');
    
    // Fetch opportunities from both pipelines
    console.log(`🔍 Fetching opportunities for Altus (${altusPipelineId}) and Andries (${andriesPipelineId})...`);
    
    const [altusResponse, andriesResponse] = await Promise.all([
      axios.get(`${GHL_BASE_URL}/opportunities/search`, {
        headers: getGHLHeaders(),
        params: {
          location_id: locationId,
          limit: 100,
          pipeline_id: altusPipelineId
        }
      }).then(response => {
        console.log(`✅ Altus response: ${response.data.opportunities?.length || 0} opportunities`);
        return response;
      }).catch(err => {
        console.error('❌ Failed to fetch Altus pipeline opportunities:', err.message);
        console.error('   Response status:', err.response?.status);
        console.error('   Response data:', JSON.stringify(err.response?.data));
        return { data: { opportunities: [] } };
      }),
      axios.get(`${GHL_BASE_URL}/opportunities/search`, {
        headers: getGHLHeaders(),
        params: {
          location_id: locationId,
          limit: 100,
          pipeline_id: andriesPipelineId
        }
      }).then(response => {
        console.log(`✅ Andries response: ${response.data.opportunities?.length || 0} opportunities`);
        return response;
      }).catch(err => {
        console.error('❌ Failed to fetch Andries pipeline opportunities:', err.message);
        console.error('   Response status:', err.response?.status);
        console.error('   Response data:', JSON.stringify(err.response?.data));
        return { data: { opportunities: [] } };
      })
    ]);
    
    const altusOpportunities = altusResponse.data.opportunities || [];
    const andriesOpportunities = andriesResponse.data.opportunities || [];
    
    console.log(`📦 Raw opportunities - Altus: ${altusOpportunities.length}, Andries: ${andriesOpportunities.length}`);
    
    // Enrich opportunities with stage names
    altusOpportunities.forEach(opp => {
      opp.pipelineStageName = stageIdToName[opp.pipelineStageId] || 'Unknown';
    });
    andriesOpportunities.forEach(opp => {
      opp.pipelineStageName = stageIdToName[opp.pipelineStageId] || 'Unknown';
    });
    
    const allOpportunities = [...altusOpportunities, ...andriesOpportunities];
    
    // Log sample stage names for debugging
    if (andriesOpportunities.length > 0) {
      console.log(`📋 Sample Andries stages: ${andriesOpportunities.slice(0, 3).map(o => o.pipelineStageName).join(', ')}`);
    }
    
    console.log(`✅ Fetched ${altusOpportunities.length} Altus + ${andriesOpportunities.length} Andries opportunities`);
    
    // Define the 5 key stages to track (these are stage NAMES, not IDs)
    // We'll need to map these dynamically based on stage names from the opportunities
    const keyStageNames = {
      bookedAppointments: ['booked', 'appointment', 'scheduled'],
      callCompleted: ['call completed', 'contacted', 'responded'],
      noShowCancelledDisqualified: ['no show', 'cancelled', 'disqualified', 'lost', 'reschedule'],
      deposits: ['deposit', 'paid deposit'],
      cashCollected: ['sold', 'purchased', 'cash collected', 'payment received']
    };
    
    // Helper function to match stage name to key stage category
    const matchStageCategory = (stageName) => {
      if (!stageName) return 'other';
      const lowerStageName = stageName.toLowerCase();
      
      if (keyStageNames.bookedAppointments.some(keyword => lowerStageName.includes(keyword))) {
        return 'bookedAppointments';
      }
      if (keyStageNames.callCompleted.some(keyword => lowerStageName.includes(keyword))) {
        return 'callCompleted';
      }
      if (keyStageNames.noShowCancelledDisqualified.some(keyword => lowerStageName.includes(keyword))) {
        return 'noShowCancelledDisqualified';
      }
      if (keyStageNames.deposits.some(keyword => lowerStageName.includes(keyword))) {
        return 'deposits';
      }
      if (keyStageNames.cashCollected.some(keyword => lowerStageName.includes(keyword))) {
        return 'cashCollected';
      }
      return 'other';
    };
    
    // Initialize stats structure
    const stats = {
      overview: {
        totalOpportunities: allOpportunities.length,
        altusCount: altusOpportunities.length,
        andriesCount: andriesOpportunities.length,
        bookedAppointments: 0,
        callCompleted: 0,
        noShowCancelledDisqualified: 0,
        deposits: 0,
        cashCollected: 0,
        totalMonetaryValue: 0
      },
      byPipeline: {
        altus: {
          pipelineId: altusPipelineId,
          pipelineName: 'Altus Pipeline - DDM',
          totalOpportunities: altusOpportunities.length,
          bookedAppointments: 0,
          callCompleted: 0,
          noShowCancelledDisqualified: 0,
          deposits: 0,
          cashCollected: 0,
          totalMonetaryValue: 0,
          salesAgents: {}
        },
        andries: {
          pipelineId: andriesPipelineId,
          pipelineName: 'Andries Pipeline - DDM',
          totalOpportunities: andriesOpportunities.length,
          bookedAppointments: 0,
          callCompleted: 0,
          noShowCancelledDisqualified: 0,
          deposits: 0,
          cashCollected: 0,
          totalMonetaryValue: 0,
          salesAgents: {}
        }
      },
      bySalesAgent: {},
      byCampaign: {}
    };
    
    // Process opportunities
    const processOpportunities = (opportunities, pipelineKey) => {
      opportunities.forEach(opp => {
        const stageName = opp.pipelineStageName || '';
        const stageCategory = matchStageCategory(stageName);
        const monetaryValue = opp.monetaryValue || 0;
        const salesAgent = opp.assignedTo || 'unassigned';
        const salesAgentName = opp.assignedToName || opp.assignedTo || 'Unassigned';
        
        // Extract campaign/ad information from attributions
        const lastAttribution = opp.attributions && opp.attributions.length > 0 
          ? opp.attributions.find(attr => attr.isLast) || opp.attributions[opp.attributions.length - 1]
          : null;
        
        const campaignName = lastAttribution?.utmCampaign || 'Unknown Campaign';
        const campaignSource = lastAttribution?.utmSource || '';
        const campaignMedium = lastAttribution?.utmMedium || '';
        const campaignKey = `${campaignName}|${campaignSource}|${campaignMedium}`;
        
        // Update overview stats
        if (stageCategory === 'bookedAppointments') stats.overview.bookedAppointments++;
        if (stageCategory === 'callCompleted') stats.overview.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') stats.overview.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') stats.overview.deposits++;
        if (stageCategory === 'cashCollected') {
          stats.overview.cashCollected++;
          stats.overview.totalMonetaryValue += monetaryValue;
        }
        
        // Extract ad information with better naming and URL support
        const adId = lastAttribution?.utmAdId || lastAttribution?.utmContent || lastAttribution?.utmTerm || 'Unknown Ad';
        const adName = lastAttribution?.utmContent || lastAttribution?.utmTerm || adId;
        const adSource = lastAttribution?.adSource || lastAttribution?.utmSource || '';
        const fbclid = lastAttribution?.fbclid || '';
        const gclid = lastAttribution?.gclid || '';
        
        // Try to construct ad URL if we have Facebook ad ID
        let adUrl = '';
        if (adId && adId !== 'Unknown Ad' && campaignSource.toLowerCase().includes('facebook')) {
          adUrl = `https://www.facebook.com/ads/library/?id=${adId}`;
        }
        
        const adKey = `${campaignKey}|${adId}`;
        
        // Initialize campaign if not exists
        if (!stats.byCampaign[campaignKey]) {
          stats.byCampaign[campaignKey] = {
            campaignName,
            campaignSource,
            campaignMedium,
            campaignKey,
            totalOpportunities: 0,
            bookedAppointments: 0,
            callCompleted: 0,
            noShowCancelledDisqualified: 0,
            deposits: 0,
            cashCollected: 0,
            totalMonetaryValue: 0,
            ads: {}
          };
        }
        
        // Update campaign stats
        const campaignStats = stats.byCampaign[campaignKey];
        campaignStats.totalOpportunities++;
        if (stageCategory === 'bookedAppointments') campaignStats.bookedAppointments++;
        if (stageCategory === 'callCompleted') campaignStats.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') campaignStats.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') campaignStats.deposits++;
        if (stageCategory === 'cashCollected') {
          campaignStats.cashCollected++;
          campaignStats.totalMonetaryValue += monetaryValue;
        }
        
        // Initialize ad if not exists
        if (!campaignStats.ads[adKey]) {
          campaignStats.ads[adKey] = {
            adId,
            adName,
            adSource,
            adUrl,
            fbclid,
            gclid,
            totalOpportunities: 0,
            bookedAppointments: 0,
            callCompleted: 0,
            noShowCancelledDisqualified: 0,
            deposits: 0,
            cashCollected: 0,
            totalMonetaryValue: 0
          };
        }
        
        // Update ad stats
        const adStats = campaignStats.ads[adKey];
        adStats.totalOpportunities++;
        if (stageCategory === 'bookedAppointments') adStats.bookedAppointments++;
        if (stageCategory === 'callCompleted') adStats.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') adStats.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') adStats.deposits++;
        if (stageCategory === 'cashCollected') {
          adStats.cashCollected++;
          adStats.totalMonetaryValue += monetaryValue;
        }
        
        // Update pipeline-specific stats
        const pipelineStats = stats.byPipeline[pipelineKey];
        if (stageCategory === 'bookedAppointments') pipelineStats.bookedAppointments++;
        if (stageCategory === 'callCompleted') pipelineStats.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') pipelineStats.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') pipelineStats.deposits++;
        if (stageCategory === 'cashCollected') {
          pipelineStats.cashCollected++;
          pipelineStats.totalMonetaryValue += monetaryValue;
        }
        
        // Initialize sales agent if not exists (pipeline level)
        if (!pipelineStats.salesAgents[salesAgent]) {
          pipelineStats.salesAgents[salesAgent] = {
            agentId: salesAgent,
            agentName: salesAgentName,
            pipelineName: pipelineStats.pipelineName,
            totalOpportunities: 0,
            bookedAppointments: 0,
            callCompleted: 0,
            noShowCancelledDisqualified: 0,
            deposits: 0,
            cashCollected: 0,
            totalMonetaryValue: 0
          };
        }
        
        // Update sales agent stats (pipeline level)
        const agentStats = pipelineStats.salesAgents[salesAgent];
        agentStats.totalOpportunities++;
        if (stageCategory === 'bookedAppointments') agentStats.bookedAppointments++;
        if (stageCategory === 'callCompleted') agentStats.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') agentStats.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') agentStats.deposits++;
        if (stageCategory === 'cashCollected') {
          agentStats.cashCollected++;
          agentStats.totalMonetaryValue += monetaryValue;
        }
        
        // Initialize sales agent if not exists (global level)
        if (!stats.bySalesAgent[salesAgent]) {
          stats.bySalesAgent[salesAgent] = {
            agentId: salesAgent,
            agentName: salesAgentName,
            pipelines: {},
            totalOpportunities: 0,
            bookedAppointments: 0,
            callCompleted: 0,
            noShowCancelledDisqualified: 0,
            deposits: 0,
            cashCollected: 0,
            totalMonetaryValue: 0
          };
        }
        
        // Update global sales agent stats
        const globalAgentStats = stats.bySalesAgent[salesAgent];
        globalAgentStats.totalOpportunities++;
        if (stageCategory === 'bookedAppointments') globalAgentStats.bookedAppointments++;
        if (stageCategory === 'callCompleted') globalAgentStats.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') globalAgentStats.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') globalAgentStats.deposits++;
        if (stageCategory === 'cashCollected') {
          globalAgentStats.cashCollected++;
          globalAgentStats.totalMonetaryValue += monetaryValue;
        }
        
        // Track pipeline breakdown for this agent
        if (!globalAgentStats.pipelines[pipelineKey]) {
          globalAgentStats.pipelines[pipelineKey] = {
            pipelineName: pipelineStats.pipelineName,
            totalOpportunities: 0,
            bookedAppointments: 0,
            callCompleted: 0,
            noShowCancelledDisqualified: 0,
            deposits: 0,
            cashCollected: 0,
            totalMonetaryValue: 0
          };
        }
        
        const agentPipelineStats = globalAgentStats.pipelines[pipelineKey];
        agentPipelineStats.totalOpportunities++;
        if (stageCategory === 'bookedAppointments') agentPipelineStats.bookedAppointments++;
        if (stageCategory === 'callCompleted') agentPipelineStats.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') agentPipelineStats.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') agentPipelineStats.deposits++;
        if (stageCategory === 'cashColleted') {
          agentPipelineStats.cashCollected++;
          agentPipelineStats.totalMonetaryValue += monetaryValue;
        }
      });
    };
    
    // Process both pipelines
    processOpportunities(altusOpportunities, 'altus');
    processOpportunities(andriesOpportunities, 'andries');
    
    // Convert sales agents objects to arrays
    stats.byPipeline.altus.salesAgentsList = Object.values(stats.byPipeline.altus.salesAgents);
    stats.byPipeline.andries.salesAgentsList = Object.values(stats.byPipeline.andries.salesAgents);
    stats.salesAgentsList = Object.values(stats.bySalesAgent);
    
    // Convert campaigns to array and sort by total opportunities (descending)
    stats.campaignsList = Object.values(stats.byCampaign).map(campaign => {
      // Convert ads object to array and sort by opportunities
      campaign.adsList = Object.values(campaign.ads).sort((a, b) => {
        return b.totalOpportunities - a.totalOpportunities;
      });
      delete campaign.ads; // Remove the object, keep only the array
      return campaign;
    }).sort((a, b) => {
      return b.totalOpportunities - a.totalOpportunities;
    });
    
    // Clean up (remove the objects, keep only arrays)
    delete stats.byPipeline.altus.salesAgents;
    delete stats.byPipeline.andries.salesAgents;
    delete stats.bySalesAgent;
    delete stats.byCampaign;
    
    console.log('✅ Pipeline performance analytics calculated successfully');
    console.log(`📊 Found ${stats.campaignsList.length} unique campaigns`);
    
    res.json({
      success: true,
      ...stats,
      locationUsed: { id: locationId, name: 'MedWave™ (SA)' },
      pipelinesUsed: [
        { id: altusPipelineId, name: 'Altus Pipeline - DDM' },
        { id: andriesPipelineId, name: 'Andries Pipeline - DDM' }
      ]
    });
    
  } catch (error) {
    console.error('❌ Error calculating pipeline performance:', error.message);
    console.error('❌ Response status:', error.response?.status);
    console.error('❌ Response data:', error.response?.data);
    res.status(error.response?.status || 500).json({
      success: false,
      error: error.response?.data || error.message,
      message: 'Failed to calculate pipeline performance'
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
