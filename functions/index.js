const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const axios = require('axios');
// Cumulative metrics functions for parallel tracking system
const { storeStageTransition, getCumulativeStageMetrics, syncOpportunitiesFromAPI } = require('./lib/opportunityHistoryService');

// Initialize Firebase Admin SDK
admin.initializeApp();

const app = express();

// CORS configuration - Allow all origins with explicit configuration
const corsOptions = {
  origin: true,
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions)); // Enable pre-flight for all routes

app.use(express.json());

// GoHighLevel API configuration
const GHL_BASE_URL = 'https://services.leadconnectorhq.com';
// Use Firebase Functions config for production, or environment variable for local development
const GHL_API_KEY = functions.config().ghl?.api_key || process.env.GHL_API_KEY;

// Validate API key is configured
if (!GHL_API_KEY) {
  console.warn('⚠️ WARNING: GHL_API_KEY not configured!');
  console.warn('   Production: Run "firebase functions:config:set ghl.api_key=YOUR_KEY"');
  console.warn('   Local: Copy functions/.env.template to functions/.env and configure your API key');
}

// Default headers for GoHighLevel API
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

// APK Download endpoint - Generate signed URL for Android app download
app.get('/api/download/apk', async (req, res) => {
  try {
    console.log('📱 Generating APK download URL...');
    
    const bucket = admin.storage().bucket();
    const file = bucket.file('downloads/apks/MedWave-v1.2.12.apk');
    
    // Check if file exists
    const [exists] = await file.exists();
    if (!exists) {
      console.error('❌ APK file not found in Firebase Storage');
      return res.status(404).json({ 
        error: 'APK file not found. Please contact support.' 
      });
    }
    
    // Generate signed URL valid for 1 hour
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + 60 * 60 * 1000 // 1 hour from now
    });
    
    // Get file metadata for size information
    const [metadata] = await file.getMetadata();
    const fileSizeMB = (metadata.size / (1024 * 1024)).toFixed(1);
    
    console.log(`✅ Generated download URL for APK (${fileSizeMB} MB)`);
    
    res.json({
      downloadUrl: url,
      version: '1.2.12',
      size: `${fileSizeMB} MB`,
      fileName: 'MedWave-v1.2.12.apk',
      expiresIn: '1 hour'
    });
    
  } catch (error) {
    console.error('❌ Error generating APK download URL:', error.message);
    res.status(500).json({ 
      error: 'Failed to generate download URL. Please try again later.',
      details: error.message 
    });
  }
});

// Specific endpoints for GoHighLevel API
app.get('/api/ghl/pipelines', async (req, res) => {
  try {
    console.log('📊 Fetching pipelines from GoHighLevel...');
    
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    console.log(`🎯 Using MedWave SA location ID: ${locationId}`);
    
    const response = await axios.get(`${GHL_BASE_URL}/opportunities/pipelines`, {
      headers: getGHLHeaders(),
      params: {
        locationId: locationId,
        ...req.query
      }
    });
    
    console.log(`✅ Retrieved ${response.data.pipelines?.length || 0} pipelines`);
    
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
    res.status(error.response?.status || 500).json({
      error: error.response?.data || error.message,
      status: error.response?.status
    });
  }
});

app.get('/api/ghl/opportunities/search', async (req, res) => {
  try {
    console.log('💼 Fetching opportunities from GoHighLevel...');
    
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    console.log(`🎯 Using MedWave SA location ID: ${locationId}`);
    
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
    res.status(error.response?.status || 500).json({
      error: error.response?.data || error.message
    });
  }
});

// Pipeline Performance Analytics Endpoint (Altus + Andries) - SNAPSHOT VIEW
app.get('/api/ghl/analytics/pipeline-performance', async (req, res) => {
  try {
    console.log('📊 [DEPRECATED] Calculating SNAPSHOT pipeline performance analytics...');
    
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    const altusPipelineId = req.query.altusPipelineId || 'AUduOJBB2lxlsEaNmlJz';
    const andriesPipelineId = req.query.andriesPipelineId || 'XeAGJWRnUGJ5tuhXam2g';
    
    // Fetch pipelines to get stage ID to name mapping
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
    
    // Fetch users to get agent names
    let userIdToName = {};
    try {
      const usersResponse = await axios.get(`${GHL_BASE_URL}/users/`, {
        headers: getGHLHeaders(),
        params: { locationId }
      });
      
      if (usersResponse.data.users) {
        usersResponse.data.users.forEach(user => {
          userIdToName[user.id] = user.name || user.email || user.id;
        });
        console.log('👥 User ID to Name mapping created:', Object.keys(userIdToName).length, 'users');
      }
    } catch (error) {
      console.log('⚠️  Could not fetch users, will use IDs as names:', error.message);
    }
    
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
      }),
      axios.get(`${GHL_BASE_URL}/opportunities/search`, {
        headers: getGHLHeaders(),
        params: {
          location_id: locationId,
          limit: 100,
          pipeline_id: andriesPipelineId
        }
      })
    ]);
    
    let altusOpportunities = altusResponse.data.opportunities || [];
    let andriesOpportunities = andriesResponse.data.opportunities || [];
    
    console.log(`✅ Altus response: ${altusOpportunities.length} opportunities`);
    console.log(`✅ Andries response: ${andriesOpportunities.length} opportunities`);
    
    // Enrich opportunities with stage names
    altusOpportunities = altusOpportunities.map(opp => ({
      ...opp,
      pipelineStageName: stageIdToName[opp.pipelineStageId] || opp.pipelineStageId
    }));
    
    andriesOpportunities = andriesOpportunities.map(opp => ({
      ...opp,
      pipelineStageName: stageIdToName[opp.pipelineStageId] || opp.pipelineStageId
    }));
    
    console.log(`📦 Raw opportunities - Altus: ${altusOpportunities.length}, Andries: ${andriesOpportunities.length}`);
    console.log(`✅ Fetched ${altusOpportunities.length} Altus + ${andriesOpportunities.length} Andries opportunities`);
    
    // Stage matching function
    const matchStageCategory = (stageName) => {
      const lowerStageName = stageName.toLowerCase();
      
      if (lowerStageName.includes('booked') && lowerStageName.includes('appointment')) {
        return 'bookedAppointments';
      }
      if (lowerStageName.includes('call') && lowerStageName.includes('completed')) {
        return 'callCompleted';
      }
      if (lowerStageName.includes('no show') || lowerStageName.includes('cancel') || lowerStageName.includes('disqualif')) {
        return 'noShowCancelledDisqualified';
      }
      if (lowerStageName.includes('deposit')) {
        return 'deposits';
      }
      if (lowerStageName.includes('cash') && lowerStageName.includes('collect')) {
        return 'cashCollected';
      }
      
      return null;
    };
    
    // Initialize stats structure
    const stats = {
      overview: {
        totalOpportunities: 0,
        bookedAppointments: 0,
        callCompleted: 0,
        noShowCancelledDisqualified: 0,
        deposits: 0,
        cashCollected: 0,
        totalMonetaryValue: 0
      },
      byPipeline: {
        altus: {
          pipelineName: 'Altus Pipeline - DDM',
          pipelineId: altusPipelineId,
          totalOpportunities: 0,
          bookedAppointments: 0,
          callCompleted: 0,
          noShowCancelledDisqualified: 0,
          deposits: 0,
          cashCollected: 0,
          totalMonetaryValue: 0,
          salesAgents: {}
        },
        andries: {
          pipelineName: 'Andries Pipeline - DDM',
          pipelineId: andriesPipelineId,
          totalOpportunities: 0,
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
        const salesAgentName = salesAgent === 'unassigned' 
          ? 'Unassigned' 
          : (userIdToName[salesAgent] || opp.assignedToName || salesAgent);
        
        // Extract campaign/ad information from attributions
        const lastAttribution = opp.attributions && opp.attributions.length > 0 
          ? opp.attributions.find(attr => attr.isLast) || opp.attributions[opp.attributions.length - 1]
          : null;
        
        const campaignName = lastAttribution?.utmCampaign || '';
        const campaignSource = lastAttribution?.utmSource || '';
        const campaignMedium = lastAttribution?.utmMedium || '';
        
        // 🎯 FILTER: Skip opportunities without UTM campaign tracking (non-ad leads)
        // Only include leads that have proper ad tracking (utmCampaign must exist)
        if (!campaignName) {
          console.log(`⏭️  Skipping non-ad lead: ${opp.name} (Source: ${opp.source || 'None'})`);
          return; // Skip this opportunity - it's not from an ad
        }
        
        const campaignKey = `${campaignName}|${campaignSource}|${campaignMedium}`;
        
        // Update overview stats
        stats.overview.totalOpportunities++;
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
        pipelineStats.totalOpportunities++;
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
        
        // Update pipeline-level sales agent stats
        const pipelineAgentStats = pipelineStats.salesAgents[salesAgent];
        pipelineAgentStats.totalOpportunities++;
        if (stageCategory === 'bookedAppointments') pipelineAgentStats.bookedAppointments++;
        if (stageCategory === 'callCompleted') pipelineAgentStats.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') pipelineAgentStats.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') pipelineAgentStats.deposits++;
        if (stageCategory === 'cashCollected') {
          pipelineAgentStats.cashCollected++;
          pipelineAgentStats.totalMonetaryValue += monetaryValue;
        }
        
        // Initialize global sales agent if not exists
        if (!stats.bySalesAgent[salesAgent]) {
          stats.bySalesAgent[salesAgent] = {
            agentId: salesAgent,
            agentName: salesAgentName,
            totalOpportunities: 0,
            bookedAppointments: 0,
            callCompleted: 0,
            noShowCancelledDisqualified: 0,
            deposits: 0,
            cashCollected: 0,
            totalMonetaryValue: 0,
            byPipeline: {
              altus: {
                totalOpportunities: 0,
                bookedAppointments: 0,
                callCompleted: 0,
                noShowCancelledDisqualified: 0,
                deposits: 0,
                cashCollected: 0,
                totalMonetaryValue: 0
              },
              andries: {
                totalOpportunities: 0,
                bookedAppointments: 0,
                callCompleted: 0,
                noShowCancelledDisqualified: 0,
                deposits: 0,
                cashCollected: 0,
                totalMonetaryValue: 0
              }
            }
          };
        }
        
        // Update global sales agent stats
        const agentStats = stats.bySalesAgent[salesAgent];
        agentStats.totalOpportunities++;
        if (stageCategory === 'bookedAppointments') agentStats.bookedAppointments++;
        if (stageCategory === 'callCompleted') agentStats.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') agentStats.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') agentStats.deposits++;
        if (stageCategory === 'cashCollected') {
          agentStats.cashCollected++;
          agentStats.totalMonetaryValue += monetaryValue;
        }
        
        // Update agent stats by pipeline
        const agentPipelineStats = agentStats.byPipeline[pipelineKey];
        agentPipelineStats.totalOpportunities++;
        if (stageCategory === 'bookedAppointments') agentPipelineStats.bookedAppointments++;
        if (stageCategory === 'callCompleted') agentPipelineStats.callCompleted++;
        if (stageCategory === 'noShowCancelledDisqualified') agentPipelineStats.noShowCancelledDisqualified++;
        if (stageCategory === 'deposits') agentPipelineStats.deposits++;
        if (stageCategory === 'cashCollected') {
          agentPipelineStats.cashCollected++;
          agentPipelineStats.totalMonetaryValue += monetaryValue;
        }
      });
    };
    
    // Process both pipelines
    processOpportunities(altusOpportunities, 'altus');
    processOpportunities(andriesOpportunities, 'andries');
    
    // Convert sales agents to array and sort by total opportunities
    stats.byPipeline.altus.salesAgentsList = Object.values(stats.byPipeline.altus.salesAgents).sort((a, b) => {
      return b.totalOpportunities - a.totalOpportunities;
    });
    
    stats.byPipeline.andries.salesAgentsList = Object.values(stats.byPipeline.andries.salesAgents).sort((a, b) => {
      return b.totalOpportunities - a.totalOpportunities;
    });
    
    stats.salesAgentsList = Object.values(stats.bySalesAgent).sort((a, b) => {
      return b.totalOpportunities - a.totalOpportunities;
    });
    
    // Convert campaigns to array and sort by total opportunities
    stats.campaignsList = Object.values(stats.byCampaign).map(campaign => {
      campaign.adsList = Object.values(campaign.ads).sort((a, b) => {
        return b.totalOpportunities - a.totalOpportunities;
      });
      delete campaign.ads;
      return campaign;
    }).sort((a, b) => {
      return b.totalOpportunities - a.totalOpportunities;
    });
    
    // Clean up
    delete stats.byPipeline.altus.salesAgents;
    delete stats.byPipeline.andries.salesAgents;
    delete stats.bySalesAgent;
    delete stats.byCampaign;
    
    console.log('✅ Pipeline performance analytics calculated successfully');
    console.log(`📊 Found ${stats.campaignsList.length} unique campaigns`);
    
    res.json(stats);
    
  } catch (error) {
    console.error('❌ Error calculating pipeline performance:', error.message);
    console.error('Stack:', error.stack);
    res.status(500).json({
      error: error.message,
      message: 'Failed to calculate pipeline performance'
    });
  }
});

// ============================================================================
// WEBHOOK ENDPOINTS - GoHighLevel Event Processing
// ============================================================================

/**
 * Sync endpoint to fetch opportunities from GoHighLevel and update Firestore history
 * Parallel system - does not affect snapshot view
 * Fixed: location_id parameter (snake_case required by GHL API)
 */
app.post('/api/ghl/sync-opportunity-history', async (req, res) => {
  try {
    console.log('🔄 Starting opportunity history sync from GoHighLevel API...');
    
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    const altusPipelineId = req.query.altusPipelineId || 'AUduOJBB2lxlsEaNmlJz';
    const andriesPipelineId = req.query.andriesPipelineId || 'XeAGJWRnUGJ5tuhXam2g';
    
    // Fetch pipelines to get stage mappings
    console.log('📋 Fetching pipeline information...');
    const pipelinesResponse = await axios.get(`${GHL_BASE_URL}/opportunities/pipelines`, {
      headers: getGHLHeaders(),
      params: { locationId: locationId }
    });
    
    const pipelines = pipelinesResponse.data.pipelines || [];
    const pipelineStages = {};
    pipelines.forEach(pipeline => {
      pipelineStages[pipeline.id] = pipeline;
    });
    
    console.log(`✅ Loaded ${pipelines.length} pipelines`);
    
    // Fetch users to get agent names
    console.log('👥 Fetching users...');
    const usersResponse = await axios.get(`${GHL_BASE_URL}/users/`, {
      headers: getGHLHeaders(),
      params: { locationId: locationId }
    });
    
    const usersData = usersResponse.data.users || [];
    const users = {};
    usersData.forEach(user => {
      users[user.id] = user;
    });
    
    console.log(`✅ Loaded ${usersData.length} users`);
    
    // Fetch opportunities from both pipelines
    console.log('🔍 Fetching opportunities from both pipelines...');
    
    const fetchOpportunities = async (pipelineId) => {
      // Fetch all opportunities for this pipeline
      // Note: GHL API limit is max 100, so we just fetch the first 100
      // In production, you may want to implement pagination if needed
      const response = await axios.get(`${GHL_BASE_URL}/opportunities/search`, {
        headers: getGHLHeaders(),
        params: {
          location_id: locationId,
          pipeline_id: pipelineId,
          limit: 100
        }
      });
      
      return response.data.opportunities || [];
    };
    
    const [altusOpportunities, andriesOpportunities] = await Promise.all([
      fetchOpportunities(altusPipelineId),
      fetchOpportunities(andriesPipelineId)
    ]);
    
    const allOpportunities = [...altusOpportunities, ...andriesOpportunities];
    
    console.log(`✅ Found ${allOpportunities.length} total opportunities (Altus: ${altusOpportunities.length}, Andries: ${andriesOpportunities.length})`);
    
    // Sync opportunities to Firestore
    const syncStats = await syncOpportunitiesFromAPI(allOpportunities, pipelineStages, users);
    
    console.log('✅ Sync completed successfully');
    
    res.json({
      success: true,
      message: 'Opportunity history sync completed',
      stats: {
        total: allOpportunities.length,
        synced: syncStats.synced,
        skipped: syncStats.skipped,
        errors: syncStats.errors
      },
      details: syncStats.details.slice(0, 10) // Return first 10 details
    });
    
  } catch (error) {
    console.error('❌ Error syncing opportunity history:', error);
    console.error('Error details:', {
      message: error.message,
      response: error.response?.data,
      status: error.response?.status,
      config: {
        url: error.config?.url,
        params: error.config?.params
      }
    });
    res.status(500).json({
      error: 'Failed to sync opportunity history',
      message: error.message,
      details: error.response?.data
    });
  }
});

/**
 * Cumulative Pipeline Performance Analytics Endpoint
 * Returns cumulative metrics where stage counts never decrease
 * Parallel system - does not affect snapshot endpoint
 */
app.get('/api/ghl/analytics/pipeline-performance-cumulative', async (req, res) => {
  try {
    console.log('📊 Calculating CUMULATIVE pipeline performance analytics...');
    
    const altusPipelineId = req.query.altusPipelineId || 'AUduOJBB2lxlsEaNmlJz';
    const andriesPipelineId = req.query.andriesPipelineId || 'XeAGJWRnUGJ5tuhXam2g';
    
    // Date range parameters (default to last 30 days)
    const endDate = req.query.endDate ? new Date(req.query.endDate) : new Date();
    const startDate = req.query.startDate 
      ? new Date(req.query.startDate) 
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    
    console.log(`📅 Date range: ${startDate.toISOString()} to ${endDate.toISOString()}`);
    
    // Fetch cumulative metrics from Firestore
    const pipelineIds = [altusPipelineId, andriesPipelineId];
    const cumulativeData = await getCumulativeStageMetrics(pipelineIds, startDate, endDate);
    
    console.log('✅ Cumulative analytics calculated successfully');
    
    res.json({
      success: true,
      viewMode: 'cumulative',
      dateRange: {
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString()
      },
      ...cumulativeData
    });
    
  } catch (error) {
    console.error('❌ Error calculating cumulative analytics:', error);
    res.status(500).json({
      error: 'Failed to calculate cumulative analytics',
      message: error.message
    });
  }
});

/**
 * Webhook endpoint for OpportunityStageUpdate events from GoHighLevel
 * DEPRECATED - Use direct API sync endpoint instead
 * Kept for backwards compatibility
 */
app.post('/api/ghl/webhooks/opportunity-stage-update', async (req, res) => {
  try {
    console.log('🪝 Received OpportunityStageUpdate webhook');
    console.log('📦 Payload:', JSON.stringify(req.body, null, 2));
    
    const webhookData = req.body;
    
    // Validate webhook data structure
    if (!webhookData || !webhookData.id) {
      console.error('❌ Invalid webhook payload - missing opportunity ID');
      return res.status(400).json({ error: 'Invalid webhook payload' });
    }
    
    const opportunityId = webhookData.id;
    const opportunityName = webhookData.name || 'Unknown';
    const contactId = webhookData.contact?.id || '';
    const pipelineId = webhookData.pipelineId || '';
    const pipelineStageId = webhookData.pipelineStageId || '';
    const previousPipelineStageId = webhookData.oldPipelineStageId || '';
    
    console.log(`🔄 Stage change for opportunity: ${opportunityName} (${opportunityId})`);
    console.log(`   Pipeline: ${pipelineId}`);
    console.log(`   Previous Stage: ${previousPipelineStageId} → New Stage: ${pipelineStageId}`);
    
    // Fetch full opportunity details to get attributions and other metadata
    try {
      const oppResponse = await axios.get(
        `${GHL_BASE_URL}/opportunities/${opportunityId}`,
        { headers: getGHLHeaders() }
      );
      
      const opportunity = oppResponse.data.opportunity || oppResponse.data;
      
      // Extract attribution data
      const lastAttribution = opportunity.attributions?.find(attr => attr.isLast) || 
                            (opportunity.attributions && opportunity.attributions[opportunity.attributions.length - 1]);
      
      const campaignName = lastAttribution?.utmCampaign || '';
      const campaignSource = lastAttribution?.utmSource || '';
      const campaignMedium = lastAttribution?.utmMedium || '';
      const adId = lastAttribution?.utmAdId || lastAttribution?.utmContent || '';
      const adName = lastAttribution?.utmContent || adId;
      
      // Get pipeline and stage names
      let pipelineName = '';
      let previousStageName = '';
      let newStageName = '';
      
      try {
        const locationId = 'QdLXaFEqrdF0JbVbpKLw';
        const pipelinesResponse = await axios.get(
          `${GHL_BASE_URL}/opportunities/pipelines`,
          { 
            headers: getGHLHeaders(),
            params: { locationId }
          }
        );
        
        const pipelines = pipelinesResponse.data.pipelines || [];
        const pipeline = pipelines.find(p => p.id === pipelineId);
        
        if (pipeline) {
          pipelineName = pipeline.name;
          const prevStage = pipeline.stages?.find(s => s.id === previousPipelineStageId);
          const newStage = pipeline.stages?.find(s => s.id === pipelineStageId);
          
          previousStageName = prevStage?.name || '';
          newStageName = newStage?.name || opportunity.pipelineStageName || '';
        }
      } catch (pipelineError) {
        console.warn('⚠️ Could not fetch pipeline details:', pipelineError.message);
        newStageName = opportunity.pipelineStageName || 'Unknown';
      }
      
      // Get assigned user name
      let assignedToName = 'Unassigned';
      const assignedTo = opportunity.assignedTo || 'unassigned';
      
      if (assignedTo && assignedTo !== 'unassigned') {
        try {
          const usersResponse = await axios.get(
            `${GHL_BASE_URL}/users/`,
            { 
              headers: getGHLHeaders(),
              params: { locationId: 'QdLXaFEqrdF0JbVbpKLw' }
            }
          );
          
          const users = usersResponse.data.users || [];
          const user = users.find(u => u.id === assignedTo);
          if (user) {
            assignedToName = user.name || user.email || assignedTo;
          }
        } catch (userError) {
          console.warn('⚠️ Could not fetch user details:', userError.message);
        }
      }
      
      // Store the stage transition in Firestore
      await storeStageTransition({
        opportunityId,
        opportunityName,
        contactId,
        pipelineId,
        pipelineName,
        previousStageId: previousPipelineStageId,
        previousStageName,
        newStageId: pipelineStageId,
        newStageName,
        campaignName,
        campaignSource,
        campaignMedium,
        adId,
        adName,
        assignedTo,
        assignedToName,
        monetaryValue: opportunity.monetaryValue || 0,
        isBackfilled: false
      });
      
      console.log(`✅ Successfully stored stage transition for ${opportunityName}`);
      
      // Respond with success
      res.status(200).json({ 
        success: true, 
        message: 'Stage transition recorded',
        opportunityId,
        newStage: newStageName
      });
      
    } catch (fetchError) {
      console.error('❌ Error fetching opportunity details:', fetchError.message);
      
      // Still try to store what we have from the webhook
      await storeStageTransition({
        opportunityId,
        opportunityName,
        contactId,
        pipelineId,
        pipelineName: '',
        previousStageId: previousPipelineStageId,
        previousStageName: '',
        newStageId: pipelineStageId,
        newStageName: '',
        campaignName: '',
        campaignSource: '',
        campaignMedium: '',
        adId: '',
        adName: '',
        assignedTo: 'unassigned',
        assignedToName: 'Unassigned',
        monetaryValue: 0,
        isBackfilled: false
      });
      
      res.status(200).json({ 
        success: true, 
        message: 'Stage transition recorded with limited data',
        warning: 'Could not fetch full opportunity details'
      });
    }
    
  } catch (error) {
    console.error('❌ Error processing webhook:', error);
    res.status(500).json({ 
      error: 'Failed to process webhook',
      message: error.message 
    });
  }
});

// Generic proxy endpoint for any GoHighLevel API call
app.all('/api/ghl/*', async (req, res) => {
  try {
    const ghlPath = req.path.replace('/api/ghl', '');
    console.log(`📡 Proxying ${req.method} request to: ${GHL_BASE_URL}${ghlPath}`);
    
    const response = await axios({
      method: req.method,
      url: `${GHL_BASE_URL}${ghlPath}`,
      headers: getGHLHeaders(),
      params: req.query,
      data: req.body
    });
    
    res.json(response.data);
    
  } catch (error) {
    console.error('❌ GoHighLevel API Error:', error.message);
    res.status(error.response?.status || 500).json({
      error: error.response?.data || error.message
    });
  }
});

// ============================================================================
// SCHEDULED FUNCTIONS - Automatic Background Sync
// ============================================================================
// Note: Scheduled function moved to Google Cloud Console for direct scheduling
// The sync logic is available via the existing /api/ghl/sync-opportunity-history endpoint

// Export the Express app as a Firebase Cloud Function (1st gen)
exports.api = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '512MB'
  })
  .https
  .onRequest(app);
