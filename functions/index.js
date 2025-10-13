const functions = require('firebase-functions');
const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();

// CORS configuration - Allow your Firebase hosting domain
app.use(cors({
  origin: [
    'http://localhost:3000',
    'http://localhost:61997',
    /^http:\/\/localhost:\d+$/,
    'https://medx-ai.web.app',
    'https://medx-ai.firebaseapp.com'
  ],
  credentials: true
}));

app.use(express.json());

// GoHighLevel API configuration
const GHL_BASE_URL = 'https://services.leadconnectorhq.com';
const GHL_API_KEY = functions.config().ghl?.api_key || 'pit-009fb0b0-1799-4773-82d2-a58cefcd9c6a';

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

// Pipeline Performance Analytics Endpoint (Altus + Andries)
app.get('/api/ghl/analytics/pipeline-performance', async (req, res) => {
  try {
    console.log('📊 Calculating pipeline performance analytics for Altus and Andries...');
    
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
        
        const campaignName = lastAttribution?.utmCampaign || 'Unknown Campaign';
        const campaignSource = lastAttribution?.utmSource || '';
        const campaignMedium = lastAttribution?.utmMedium || '';
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

// Export the Express app as a Firebase Cloud Function (2nd gen)
exports.api = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '512MB'
  })
  .https
  .onRequest(app);
