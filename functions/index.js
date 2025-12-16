const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const { Resend } = require('resend');
// Cumulative metrics functions for parallel tracking system
const { storeStageTransition, getCumulativeStageMetrics, syncOpportunitiesFromAPI, matchAndUpdateGHLDataToFacebookAds } = require('./lib/opportunityHistoryService');
// Facebook Ads sync function
const { syncFacebookAdsToFirebase } = require('./lib/facebookAdsSync');
// Advert Data sync functions
const { fetchAndStoreAdvertsFromFacebook, getGHLTotals } = require('./lib/advertDataSync');
// Facebook 6-month sync with checkpoint/resume
const { sync6MonthsFacebookData } = require('./lib/facebook6MonthSync');
// Email service for appointment notifications
const { EmailService } = require('./lib/emailService');

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

// Resend configuration for simple marketing notifications
const RESEND_API_KEY = functions.config().resend?.api_key || process.env.RESEND_API_KEY;
const resend = RESEND_API_KEY ? new Resend(RESEND_API_KEY) : null;
const MARKETING_EMAIL =
  functions.config().marketing?.deposit_email ||
  process.env.MARKETING_EMAIL ||
  'tertiusva@gmail.com';

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

// Deposit confirmation endpoint (Yes/No) - validates token and updates appointment
app.post('/deposit/confirm', async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const appointmentId =
      req.body?.appointmentId || req.body?.id || req.query.appointmentId || req.query.id;
    const decision =
      (req.body?.decision || req.query.decision || '').toString().toLowerCase();
    const token = req.body?.token || req.query.token;

    if (!appointmentId || !decision || !token) {
      return res.status(400).json({
        success: false,
        status: 'invalid',
        message: 'Missing appointmentId, decision, or token.',
      });
    }

    if (decision !== 'yes' && decision !== 'no') {
      return res.status(400).json({
        success: false,
        status: 'invalid',
        message: 'Unknown decision.',
      });
    }

    const db = admin.firestore();
    const appointmentRef = db.collection('appointments').doc(appointmentId);
    const snap = await appointmentRef.get();

    if (!snap.exists) {
      return res.status(404).json({
        success: false,
        status: 'invalid',
        message: 'Appointment not found.',
      });
    }

    const data = snap.data() || {};

    if (!data.depositConfirmationToken || data.depositConfirmationToken !== token) {
      return res.status(400).json({
        success: false,
        status: 'invalid',
        message: 'This link is invalid or has already been used.',
      });
    }

    const nowTs = admin.firestore.Timestamp.now();
    const updates = {
      depositConfirmationStatus: decision === 'yes' ? 'confirmed' : 'declined',
      depositConfirmationRespondedAt: nowTs,
      depositConfirmationToken: data.depositConfirmationToken,
    };

    // Normalize arrays
    const stageHistory = Array.isArray(data.stageHistory) ? [...data.stageHistory] : [];
    const notes = Array.isArray(data.notes) ? [...data.notes] : [];

    if (decision === 'yes') {
      if (stageHistory.length > 0) {
        const last = stageHistory[stageHistory.length - 1];
        if (!last.exitedAt) {
          stageHistory[stageHistory.length - 1] = { ...last, exitedAt: nowTs };
        }
      }

      stageHistory.push({
        stage: 'deposit_made',
        enteredAt: nowTs,
        exitedAt: null,
        note: 'Client confirmed deposit via email link',
      });

      notes.push({
        text: 'Client confirmed deposit via email link',
        createdAt: nowTs,
        createdBy: 'system-email',
        createdByName: 'Client',
      });

      Object.assign(updates, {
        currentStage: 'deposit_made',
        stageEnteredAt: nowTs,
        stageHistory: stageHistory,
        notes: notes,
      });
    } else {
      notes.push({
        text: 'Client indicated deposit not made (via email link)',
        createdAt: nowTs,
        createdBy: 'system-email',
        createdByName: 'Client',
      });

      Object.assign(updates, {
        notes: notes,
      });
    }

    await appointmentRef.update(updates);

    // Optional: notify marketing on confirmed deposit
    if (decision === 'yes' && resend) {
      try {
        await resend.emails.send({
          from: 'MedWave <no-reply@medwave.app>',
          to: MARKETING_EMAIL,
          subject: `Deposit confirmed: ${data.customerName || data.name || appointmentId}`,
          html: `
            <p>Deposit confirmed by client.</p>
            <p><strong>Appointment ID:</strong> ${appointmentId}</p>
            <p><strong>Name:</strong> ${data.customerName || data.name || 'N/A'}</p>
            <p><strong>Email:</strong> ${data.email || 'N/A'}</p>
            <p><strong>Phone:</strong> ${data.phone || 'N/A'}</p>
            <p><strong>Deposit amount:</strong> ${data.depositAmount || 'N/A'}</p>
          `,
        });
      } catch (emailErr) {
        console.warn('⚠️ Unable to send marketing email:', emailErr.message || emailErr);
      }
    }

    return res.json({
      success: true,
      status: decision === 'yes' ? 'confirmed' : 'declined',
      message:
        decision === 'yes'
          ? 'Thank you for confirming your deposit.'
          : 'We will send another reminder in 2 days to verify your deposit.',
    });
  } catch (error) {
    console.error('❌ Error handling deposit confirmation:', error);
    return res.status(500).json({
      success: false,
      status: 'invalid',
      message: 'Something went wrong. Please try again later.',
    });
  }
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
app.get('/ghl/pipelines', async (req, res) => {
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

app.get('/ghl/opportunities/search', async (req, res) => {
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
app.get('/ghl/analytics/pipeline-performance', async (req, res) => {
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
        
        // Client's UTM structure (NEW):
        // utm_source={{campaign.name}}
        // utm_medium={{adset.name}}
        // utm_campaign={{ad.name}}
        // fbc_id={{adset.id}}
        // h_ad_id={{ad.id}}
        // 
        // OLD structure (backward compatibility):
        // utm_campaign={{campaign.name}}
        // utm_content={{ad.name}}
        
        // Try NEW structure first, fallback to OLD
        const campaignName = lastAttribution?.utmSource || lastAttribution?.utmCampaign || '';
        const campaignSource = lastAttribution?.utmSource || '';
        const campaignMedium = lastAttribution?.utmMedium || '';
        const adSetName = lastAttribution?.utmMedium || lastAttribution?.utmAdset || lastAttribution?.adset || '';
        
        // 🎯 FILTER: Skip opportunities without UTM campaign tracking (non-ad leads)
        // Only include leads that have proper ad tracking (utmSource must exist since that's where campaign is)
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
        const adId = lastAttribution?.h_ad_id || lastAttribution?.utmAdId || lastAttribution?.utmContent || lastAttribution?.utmTerm || 'Unknown Ad';
        const adName = lastAttribution?.utmCampaign || lastAttribution?.utmContent || lastAttribution?.utmTerm || adId;  // Ad name is in utm_campaign
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
app.post('/ghl/sync-opportunity-history', async (req, res) => {
  try {
    console.log('🔄 Starting opportunity history sync from GoHighLevel API...');
    
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    const altusPipelineId = req.query.altusPipelineId || 'AUduOJBB2lxlsEaNmlJz';
    const andriesPipelineId = req.query.andriesPipelineId || 'XeAGJWRnUGJ5tuhXam2g';
    const davidePipelineId = req.query.davidePipelineId || 'pTbNvnrXqJc9u1oxir3q';
    
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
    
    // Fetch opportunities from all three pipelines
    console.log('🔍 Fetching opportunities from all pipelines...');
    
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
    
    const [altusOpportunities, andriesOpportunities, davideOpportunities] = await Promise.all([
      fetchOpportunities(altusPipelineId),
      fetchOpportunities(andriesPipelineId),
      fetchOpportunities(davidePipelineId)
    ]);
    
    const allOpportunities = [...altusOpportunities, ...andriesOpportunities, ...davideOpportunities];
    
    console.log(`✅ Found ${allOpportunities.length} total opportunities (Altus: ${altusOpportunities.length}, Andries: ${andriesOpportunities.length}, Davide: ${davideOpportunities.length})`);
    
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
app.get('/ghl/analytics/pipeline-performance-cumulative', async (req, res) => {
  try {
    console.log('📊 Calculating CUMULATIVE pipeline performance analytics...');
    
    const altusPipelineId = req.query.altusPipelineId || 'AUduOJBB2lxlsEaNmlJz';
    const andriesPipelineId = req.query.andriesPipelineId || 'XeAGJWRnUGJ5tuhXam2g';
    const davidePipelineId = req.query.davidePipelineId || 'pTbNvnrXqJc9u1oxir3q';
    
    // Date range parameters (default to last 30 days)
    const endDate = req.query.endDate ? new Date(req.query.endDate) : new Date();
    const startDate = req.query.startDate 
      ? new Date(req.query.startDate) 
      : new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    
    console.log(`📅 Date range: ${startDate.toISOString()} to ${endDate.toISOString()}`);
    
    // Fetch cumulative metrics from Firestore for all three pipelines
    const pipelineIds = [altusPipelineId, andriesPipelineId, davidePipelineId];
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
app.post('/ghl/webhooks/opportunity-stage-update', async (req, res) => {
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
      
      // Extract custom field values (Contract Value, R Cash Collected)
      const customFields = opportunity.customFields || [];
      let contractValue = 0;
      let cashCollectedValue = 0;
      
      customFields.forEach(field => {
        const fieldKey = field.key || field.id || '';
        const fieldValue = parseFloat(field.value) || 0;
        
        // Match custom fields by key/name
        if (fieldKey.toLowerCase().includes('contract') || fieldKey.toLowerCase().includes('value')) {
          contractValue = fieldValue;
        }
        if (fieldKey.toLowerCase().includes('cash') && fieldKey.toLowerCase().includes('collected')) {
          cashCollectedValue = fieldValue;
        }
      });
      
      // Use custom field value if available, otherwise fall back to standard monetaryValue
      const monetaryValue = cashCollectedValue || contractValue || opportunity.monetaryValue || 0;
      
      // Extract attribution data
      const lastAttribution = opportunity.attributions?.find(attr => attr.isLast) || 
                            (opportunity.attributions && opportunity.attributions[opportunity.attributions.length - 1]);
      
      // Client's UTM structure (NEW):
      // utm_source={{campaign.name}}
      // utm_medium={{adset.name}}
      // utm_campaign={{ad.name}}
      // fbc_id={{adset.id}}
      // h_ad_id={{ad.id}}
      // 
      // OLD structure (backward compatibility):
      // utm_campaign={{campaign.name}}
      // utm_content={{ad.name}}
      
      // Try NEW structure first, fallback to OLD
      const campaignName = lastAttribution?.utmSource || lastAttribution?.utmCampaign || '';
      const campaignSource = lastAttribution?.utmSource || '';
      const campaignMedium = lastAttribution?.utmMedium || '';
      const adSetName = lastAttribution?.utmMedium || lastAttribution?.utmAdset || lastAttribution?.adset || '';
      const adId = lastAttribution?.h_ad_id || lastAttribution?.utmAdId || lastAttribution?.utmContent || '';
      const adName = lastAttribution?.utmCampaign || lastAttribution?.utmContent || adId;
      
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
        adSetName,
        assignedTo,
        assignedToName,
        monetaryValue: monetaryValue, // Uses custom field if available
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
        adSetName: '',
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
// FACEBOOK ADS API ENDPOINTS
// ============================================================================

/**
 * Manual trigger endpoint for Facebook Ads sync
 * POST /facebook/sync-ads
 */
app.post('/facebook/sync-ads', async (req, res) => {
  try {
    console.log('🔄 Manual Facebook Ads sync triggered...');
    
    const forceRefresh = req.body?.forceRefresh !== false; // Default to true
    const datePreset = req.body?.datePreset || 'last_30d';
    
    const result = await syncFacebookAdsToFirebase(datePreset);
    
    res.json({
      success: true,
      message: 'Facebook Ads sync completed successfully',
      stats: result.stats,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Facebook Ads sync failed:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * Manual trigger endpoint for GHL to Facebook matching
 * POST /facebook/match-ghl
 */
app.post('/facebook/match-ghl', async (req, res) => {
  try {
    console.log('🔄 Manual GHL to Facebook matching triggered...');
    
    const result = await matchAndUpdateGHLDataToFacebookAds();
    
    res.json({
      success: true,
      message: 'GHL matching completed successfully',
      stats: result,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ GHL matching failed:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// ============================================================================
// ADVERT DATA API ENDPOINTS - New Collection Structure
// ============================================================================

/**
 * Sync Facebook ads to advertData collection
 * POST /advertdata/sync-facebook
 */
app.post('/advertdata/sync-facebook', async (req, res) => {
  try {
    console.log('🔄 Syncing Facebook ads to advertData collection...');
    
    const monthsBack = req.body?.monthsBack || 6;
    const result = await fetchAndStoreAdvertsFromFacebook(monthsBack);
    
    res.json({
      success: true,
      message: 'Facebook adverts synced to advertData successfully',
      stats: result.stats,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Facebook advertData sync failed:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * Get GHL totals for a specific advert
 * GET /advertdata/:adId/totals
 */
app.get('/advertdata/:adId/totals', async (req, res) => {
  try {
    const adId = req.params.adId;
    console.log(`📊 Calculating GHL totals for ad ${adId}...`);
    
    const totals = await getGHLTotals(adId);
    
    res.json({
      success: true,
      adId: adId,
      totals: totals,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error(`❌ Error getting GHL totals for ad ${req.params.adId}:`, error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * Get advertData collection stats
 * GET /advertdata/stats
 */
app.get('/advertdata/stats', async (req, res) => {
  try {
    console.log('📊 Fetching advertData collection stats...');
    
    const db = admin.firestore();
    const advertsSnapshot = await db.collection('advertData').get();
    
    let withInsights = 0;
    let withGHLData = 0;
    
    for (const advertDoc of advertsSnapshot.docs) {
      const insightsSnapshot = await advertDoc.ref.collection('insights').limit(1).get();
      if (!insightsSnapshot.empty) {
        withInsights++;
      }
      
      const ghlSnapshot = await advertDoc.ref.collection('ghlWeekly').limit(1).get();
      if (!ghlSnapshot.empty) {
        withGHLData++;
      }
    }
    
    res.json({
      success: true,
      stats: {
        totalAdverts: advertsSnapshot.size,
        withInsights: withInsights,
        withGHLData: withGHLData
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error getting advertData stats:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * Sync GHL opportunities to advertData collection
 * POST /advertdata/sync-ghl
 * 
 * Fetches opportunities directly from GHL API and matches to advertData ads
 * using h_ad_id parameter with weekly breakdown
 */
app.post('/advertdata/sync-ghl', async (req, res) => {
  try {
    console.log('🔄 Syncing GHL opportunities to advertData collection...');
    console.log('   ⚠️  Data source: GHL API ONLY (not Firebase collections)');
    
    // Import the sync functions
    const { 
      fetchAllOpportunitiesFromGHL, 
      processOpportunities, 
      groupByAdAndWeek, 
      writeToAdvertData 
    } = require('./syncGHLToAdvertData');
    
    // Step 1: Fetch opportunities from GHL API
    console.log('📋 Fetching opportunities from GHL API...');
    const opportunities = await fetchAllOpportunitiesFromGHL();
    
    if (opportunities.length === 0) {
      return res.json({
        success: true,
        message: 'No opportunities found',
        stats: {
          totalOpportunities: 0,
          withHAdId: 0,
          adsUpdated: 0,
          weeksWritten: 0
        },
        timestamp: new Date().toISOString()
      });
    }
    
    // Step 2: Process and extract UTM data
    console.log('🔍 Processing opportunities and extracting UTM parameters...');
    const { processedData, stats: extractionStats } = processOpportunities(opportunities);
    
    if (processedData.length === 0) {
      return res.json({
        success: true,
        message: 'No opportunities with h_ad_id found',
        stats: {
          totalOpportunities: opportunities.length,
          withHAdId: 0,
          adsUpdated: 0,
          weeksWritten: 0
        },
        timestamp: new Date().toISOString()
      });
    }
    
    // Step 3: Group by ad and week
    console.log('📅 Grouping opportunities by ad and week...');
    const adWeekMap = groupByAdAndWeek(processedData);
    
    // Step 4: Write to advertData
    console.log('💾 Writing data to advertData collection...');
    const writeStats = await writeToAdvertData(adWeekMap);
    
    res.json({
      success: true,
      message: 'GHL data synced to advertData successfully',
      stats: {
        totalOpportunities: opportunities.length,
        withHAdId: extractionStats.withHAdId,
        withAllUTMParams: extractionStats.withAllUTMParams,
        adsUpdated: writeStats.adsProcessed,
        weeksWritten: writeStats.weeksWritten,
        errors: writeStats.errors
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ GHL advertData sync failed:', error);
    res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// ============================================================================
// SCHEDULED FUNCTIONS - Automatic Background Sync
// ============================================================================

/**
 * Scheduled function to auto-sync GoHighLevel data to Firebase
 * Runs every 2 minutes to keep cumulative data up-to-date
 * This runs independently of user logins and ensures Firebase always has fresh data
 * 
 * DISABLED - Will be re-enabled on next deployment
 */
/*
exports.scheduledSync = functions
  .pubsub
  .schedule('every 2 minutes')
  .timeZone('Africa/Johannesburg')
  .onRun(async (context) => {
    try {
      console.log('⏰ Scheduled sync triggered at:', new Date().toISOString());
      
      const locationId = 'QdLXaFEqrdF0JbVbpKLw';
      const altusPipelineId = 'AUduOJBB2lxlsEaNmlJz';
      const andriesPipelineId = 'XeAGJWRnUGJ5tuhXam2g';
      const davidePipelineId = 'pTbNvnrXqJc9u1oxir3q';
      
      // Fetch pipelines to get stage mappings
      console.log('📋 Fetching pipeline information...');
      const pipelinesResponse = await axios.get(`${GHL_BASE_URL}/opportunities/pipelines`, {
        headers: getGHLHeaders(),
        params: { locationId }
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
        params: { locationId }
      });
      
      const usersData = usersResponse.data.users || [];
      const users = {};
      usersData.forEach(user => {
        users[user.id] = user;
      });
      
      console.log(`✅ Loaded ${usersData.length} users`);
      
      // Fetch and sync opportunities from both pipelines with pagination
      const fetchOpportunities = async (pipelineId) => {
        const allOpportunities = [];
        let hasMore = true;
        let nextCursor = undefined;
        
        while (hasMore) {
          const params = {
            location_id: locationId,
            pipelineId: pipelineId,
            limit: 100
          };
          
          if (nextCursor) {
            params.startAfterId = nextCursor;
            params.startAfter = nextCursor;
          }
          
          const response = await axios.get(`${GHL_BASE_URL}/opportunities/search`, {
            headers: getGHLHeaders(),
            params
          });
          
          const opportunities = response.data.opportunities || [];
          allOpportunities.push(...opportunities);
          
          nextCursor = response.data.meta?.nextStartAfterId || 
                       response.data.meta?.nextStartAfter;
          hasMore = !!nextCursor && opportunities.length > 0;
        }
        
        return allOpportunities;
      };
      
      console.log('🔍 Fetching opportunities from all three pipelines...');
      const [altusOpportunities, andriesOpportunities, davideOpportunities] = await Promise.all([
        fetchOpportunities(altusPipelineId),
        fetchOpportunities(andriesPipelineId),
        fetchOpportunities(davidePipelineId)
      ]);
      
      const allOpportunities = [...altusOpportunities, ...andriesOpportunities, ...davideOpportunities];
      
      console.log(`✅ Found ${allOpportunities.length} total opportunities (Altus: ${altusOpportunities.length}, Andries: ${andriesOpportunities.length}, Davide: ${davideOpportunities.length})`);
      
      // Sync to Firebase
      const syncStats = await syncOpportunitiesFromAPI(allOpportunities, pipelineStages, users);
      
      console.log('✅ Scheduled sync completed:', {
        total: allOpportunities.length,
        synced: syncStats.synced,
        skipped: syncStats.skipped,
        errors: syncStats.errors
      });
      
      return { success: true, stats: syncStats };
    } catch (error) {
      console.error('❌ Scheduled sync failed:', error);
      throw error;
    }
  });
*/

/**
 * Scheduled function to auto-sync Facebook Ads data to Firebase
 * Runs every 15 minutes to keep Facebook ad performance data up-to-date
 * 
 * DISABLED - Will be re-enabled on next deployment
 */
/*
exports.scheduledFacebookSync = functions
  .pubsub
  .schedule('every 15 minutes')
  .timeZone('Africa/Johannesburg')
  .onRun(async (context) => {
    try {
      console.log('⏰ Scheduled Facebook sync triggered at:', new Date().toISOString());
      
      const result = await syncFacebookAdsToFirebase('last_30d');
      
      console.log('✅ Scheduled Facebook sync completed:', result.stats);
      
      return { success: true, stats: result.stats };
    } catch (error) {
      console.error('❌ Scheduled Facebook sync failed:', error);
      throw error;
    }
  });
*/

// Export the Express app as a Firebase Cloud Function (1st gen)
// Ensure this is deployed so /deposit/confirm is reachable:
// firebase deploy --only functions:api
exports.api = functions
  .runWith({
    timeoutSeconds: 300,
    memory: '512MB'
  })
  .https
  .onRequest(app);

// ============================================
// APPOINTMENT EMAIL NOTIFICATION FUNCTIONS
// ============================================

/**
 * Send appointment booking confirmation email
 * Triggered when a new appointment is created
 */
exports.sendAppointmentBookingEmail = functions.firestore
  .document('appointments/{appointmentId}')
  .onCreate(async (snapshot, context) => {
    try {
      const appointment = snapshot.data();
      const appointmentId = context.params.appointmentId;
      
      console.log(`📧 Sending booking confirmation email for appointment: ${appointmentId}`);
      
      // Check if patient email exists
      if (!appointment.patientEmail) {
        console.log('⚠️ No patient email provided, skipping email notification');
        return null;
      }
      
      // Add appointment ID to the appointment object
      const appointmentWithId = { ...appointment, id: appointmentId };
      
      // Send booking confirmation email
      const result = await EmailService.sendBookingConfirmation(
        appointmentWithId,
        appointment.patientEmail
      );
      
      if (result.success) {
        // Update appointment with email sent status
        const updateData = {
          'emailNotifications.bookingConfirmationSent': true,
          'emailNotifications.bookingConfirmationSentAt': admin.firestore.FieldValue.serverTimestamp(),
        };
        if (result.messageId) {
          updateData['emailNotifications.bookingConfirmationMessageId'] = result.messageId;
        }
        await snapshot.ref.update(updateData);
        console.log(`✅ Booking confirmation email sent successfully`);
      } else {
        console.error(`❌ Failed to send booking confirmation email: ${result.error}`);
      }
      
      return result;
    } catch (error) {
      console.error('❌ Error in sendAppointmentBookingEmail:', error);
      return null;
    }
  });

/**
 * Send appointment confirmed email
 * Triggered when appointment status changes to 'confirmed'
 */
exports.sendAppointmentConfirmedEmail = functions.firestore
  .document('appointments/{appointmentId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const appointmentId = context.params.appointmentId;
      
      // Check if status changed to 'confirmed'
      if (before.status !== 'confirmed' && after.status === 'confirmed') {
        console.log(`📧 Sending appointment confirmed email for: ${appointmentId}`);
        
        // Check if patient email exists
        if (!after.patientEmail) {
          console.log('⚠️ No patient email provided, skipping email notification');
          return null;
        }
        
        // Add appointment ID to the appointment object
        const appointmentWithId = { ...after, id: appointmentId };
        
        // Send confirmed email
        const result = await EmailService.sendAppointmentConfirmed(
          appointmentWithId,
          after.patientEmail
        );
        
        if (result.success) {
          // Update appointment with email sent status
          const updateData = {
            'emailNotifications.confirmedEmailSent': true,
            'emailNotifications.confirmedEmailSentAt': admin.firestore.FieldValue.serverTimestamp(),
          };
          if (result.messageId) {
            updateData['emailNotifications.confirmedEmailMessageId'] = result.messageId;
          }
          await change.after.ref.update(updateData);
          console.log(`✅ Appointment confirmed email sent successfully`);
        } else {
          console.error(`❌ Failed to send confirmed email: ${result.error}`);
        }
        
        return result;
      }
      
      // Check if status changed to 'cancelled'
      if (before.status !== 'cancelled' && after.status === 'cancelled') {
        console.log(`📧 Sending appointment cancellation email for: ${appointmentId}`);
        
        if (!after.patientEmail) {
          console.log('⚠️ No patient email provided, skipping email notification');
          return null;
        }
        
        const appointmentWithId = { ...after, id: appointmentId };
        
        const result = await EmailService.sendAppointmentCancellation(
          appointmentWithId,
          after.patientEmail
        );
        
        if (result.success) {
          const updateData = {
            'emailNotifications.cancellationEmailSent': true,
            'emailNotifications.cancellationEmailSentAt': admin.firestore.FieldValue.serverTimestamp(),
          };
          if (result.messageId) {
            updateData['emailNotifications.cancellationEmailMessageId'] = result.messageId;
          }
          await change.after.ref.update(updateData);
          console.log(`✅ Appointment cancellation email sent successfully`);
        } else {
          console.error(`❌ Failed to send cancellation email: ${result.error}`);
        }
        
        return result;
      }
      
      return null;
    } catch (error) {
      console.error('❌ Error in sendAppointmentConfirmedEmail:', error);
      return null;
    }
  });

/**
 * Confirm appointment via email link
 * HTTP callable function
 */
exports.confirmAppointmentViaEmail = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }
  
  try {
    const appointmentId = req.query.id || req.body?.appointmentId;
    
    if (!appointmentId) {
      res.status(400).send('Missing appointment ID');
      return;
    }
    
    console.log(`✅ Confirming appointment via email link: ${appointmentId}`);
    
    // Get appointment document
    const appointmentRef = admin.firestore().collection('appointments').doc(appointmentId);
    const appointmentDoc = await appointmentRef.get();
    
    if (!appointmentDoc.exists) {
      res.status(404).send('Appointment not found');
      return;
    }
    
    // Update appointment status to confirmed
    await appointmentRef.update({
      status: 'confirmed',
      confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
      confirmedViaEmail: true
    });
    
    console.log(`✅ Appointment ${appointmentId} confirmed successfully`);
    
    // Return success HTML page
    res.send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>Appointment Confirmed</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            margin: 0;
            padding: 0;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
          }
          .container {
            background: white;
            border-radius: 12px;
            padding: 40px;
            max-width: 500px;
            text-align: center;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
          }
          .checkmark {
            font-size: 64px;
            color: #4caf50;
            margin-bottom: 20px;
          }
          h1 {
            color: #333;
            margin-bottom: 10px;
          }
          p {
            color: #666;
            line-height: 1.6;
            margin-bottom: 20px;
          }
          .button {
            display: inline-block;
            padding: 12px 30px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 6px;
            font-weight: 600;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="checkmark">✅</div>
          <h1>Appointment Confirmed!</h1>
          <p>Thank you for confirming your appointment. You will receive a confirmation email shortly.</p>
          <p>We look forward to seeing you!</p>
          <a href="#" class="button" onclick="window.close()">Close</a>
        </div>
      </body>
      </html>
    `);
    
  } catch (error) {
    console.error('❌ Error confirming appointment:', error);
    res.status(500).send('Error confirming appointment: ' + error.message);
  }
});

/**
 * Schedule appointment reminder emails
 * Runs daily to check for appointments happening tomorrow
 * 
 * DISABLED - Will be re-enabled on next deployment
 */
/*
exports.scheduleAppointmentReminders = functions.pubsub
  .schedule('every day 09:00')
  .timeZone('Africa/Johannesburg') // Adjust to your timezone
  .onRun(async (context) => {
    try {
      console.log('📧 Running daily appointment reminder check...');
      
      // Calculate tomorrow's date range
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);
      
      const dayAfterTomorrow = new Date(tomorrow);
      dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 1);
      
      // Query appointments for tomorrow that are confirmed or scheduled
      const appointmentsSnapshot = await admin.firestore()
        .collection('appointments')
        .where('startTime', '>=', admin.firestore.Timestamp.fromDate(tomorrow))
        .where('startTime', '<', admin.firestore.Timestamp.fromDate(dayAfterTomorrow))
        .where('status', 'in', ['Scheduled', 'Confirmed'])
        .get();
      
      console.log(`Found ${appointmentsSnapshot.size} appointments for tomorrow`);
      
      let sentCount = 0;
      
      // Send reminders
      for (const doc of appointmentsSnapshot.docs) {
        const appointment = doc.data();
        const appointmentId = doc.id;
        
        // Check if reminder already sent
        if (appointment.emailNotifications?.reminderSent) {
          console.log(`Reminder already sent for appointment ${appointmentId}`);
          continue;
        }
        
        // Check if patient email exists
        if (!appointment.patientEmail) {
          console.log(`No email for appointment ${appointmentId}`);
          continue;
        }
        
        // Send reminder
        const appointmentWithId = { ...appointment, id: appointmentId };
        const result = await EmailService.sendAppointmentReminder(
          appointmentWithId,
          appointment.patientEmail
        );
        
        if (result.success) {
          // Update appointment with reminder sent status
          const updateData = {
            'emailNotifications.reminderSent': true,
            'emailNotifications.reminderSentAt': admin.firestore.FieldValue.serverTimestamp(),
          };
          if (result.messageId) {
            updateData['emailNotifications.reminderMessageId'] = result.messageId;
          }
          await doc.ref.update(updateData);
          sentCount++;
          console.log(`✅ Reminder sent for appointment ${appointmentId}`);
        } else {
          console.error(`❌ Failed to send reminder for ${appointmentId}: ${result.error}`);
        }
      }
      
      console.log(`✅ Sent ${sentCount} appointment reminders`);
      return { success: true, sentCount };
      
    } catch (error) {
      console.error('❌ Error in scheduleAppointmentReminders:', error);
      throw error;
    }
  });
*/

/**
 * Scheduled Facebook 6-Month Sync
 * Runs every hour to fetch Facebook ads and insights from the last 6 months
 * Handles rate limits with automatic checkpoint/resume
 * 
 * DISABLED - Will be re-enabled on next deployment
 */
/*
exports.scheduledFacebook6MonthSync = functions.pubsub
  .schedule('every 1 hours')
  .timeZone('Africa/Johannesburg')
  .onRun(async (context) => {
    try {
      console.log('🚀 Starting scheduled Facebook 6-month sync...');
      
      const result = await sync6MonthsFacebookData();
      
      if (result.success) {
        console.log('✅ Facebook 6-month sync completed successfully');
        console.log('📊 Stats:', result.stats);
      } else if (result.rateLimited) {
        console.log('⚠️  Rate limit hit - will retry next hour');
        console.log('📊 Progress:', result.progress);
      } else {
        console.log('❌ Sync failed:', result.message);
      }
      
      return result;
    } catch (error) {
      console.error('❌ Error in scheduled Facebook 6-month sync:', error);
      throw error;
    }
  });
*/
