/**
 * Backfill script to populate opportunityStageHistory collection
 * with current opportunities from GoHighLevel
 * 
 * This should be run ONCE after deploying the cumulative metrics system
 * 
 * Usage: node backfillOpportunityHistory.js
 */

const admin = require('firebase-admin');
const axios = require('axios');
const { storeStageTransition } = require('./lib/opportunityHistoryService');

// Initialize Firebase Admin
// Check if running in Cloud Functions environment
if (!admin.apps.length) {
  // Local environment - use service account
  try {
    const serviceAccount = require('../bhl-obe-firebase-adminsdk-fbsvc-68c34b6ad7.json');
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'medx-ai'
    });
  } catch (error) {
    console.log('⚠️ Could not load service account, trying default credentials...');
    admin.initializeApp();
  }
}

// GoHighLevel configuration
const GHL_BASE_URL = 'https://services.leadconnectorhq.com';
const GHL_API_KEY = process.env.GHL_API_KEY || 'pit-009fb0b0-1799-4773-82d2-a58cefcd9c6a';

const getGHLHeaders = () => ({
  'Authorization': `Bearer ${GHL_API_KEY}`,
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'User-Agent': 'MedWave-Backfill/1.0',
  'Version': '2021-07-28'
});

async function backfillOpportunityHistory() {
  try {
    console.log('🔄 Starting opportunity history backfill...');
    
    const locationId = 'QdLXaFEqrdF0JbVbpKLw';
    const altusPipelineId = 'AUduOJBB2lxlsEaNmlJz';
    const andriesPipelineId = 'XeAGJWRnUGJ5tuhXam2g';
    
    // Fetch pipelines to get stage names
    console.log('📋 Fetching pipeline information...');
    const pipelinesResponse = await axios.get(`${GHL_BASE_URL}/opportunities/pipelines`, {
      headers: getGHLHeaders(),
      params: { locationId }
    });
    
    const pipelines = pipelinesResponse.data.pipelines || [];
    const altusPipeline = pipelines.find(p => p.id === altusPipelineId);
    const andriesPipeline = pipelines.find(p => p.id === andriesPipelineId);
    
    // Create stage ID to name mapping
    const stageIdToName = {};
    const pipelineIdToName = {};
    
    if (altusPipeline) {
      pipelineIdToName[altusPipelineId] = altusPipeline.name;
      altusPipeline.stages?.forEach(stage => {
        stageIdToName[stage.id] = stage.name;
      });
    }
    
    if (andriesPipeline) {
      pipelineIdToName[andriesPipelineId] = andriesPipeline.name;
      andriesPipeline.stages?.forEach(stage => {
        stageIdToName[stage.id] = stage.name;
      });
    }
    
    console.log(`✅ Mapped ${Object.keys(stageIdToName).length} stages`);
    
    // Fetch users for agent names
    console.log('👥 Fetching users...');
    const userIdToName = {};
    try {
      const usersResponse = await axios.get(`${GHL_BASE_URL}/users/`, {
        headers: getGHLHeaders(),
        params: { locationId }
      });
      
      if (usersResponse.data.users) {
        usersResponse.data.users.forEach(user => {
          userIdToName[user.id] = user.name || user.email || user.id;
        });
        console.log(`✅ Mapped ${Object.keys(userIdToName).length} users`);
      }
    } catch (error) {
      console.warn('⚠️ Could not fetch users:', error.message);
    }
    
    // Fetch all opportunities from both pipelines
    console.log('🔍 Fetching opportunities from both pipelines...');
    
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
    
    const allOpportunities = [
      ...(altusResponse.data.opportunities || []).map(opp => ({ ...opp, pipelineId: altusPipelineId })),
      ...(andriesResponse.data.opportunities || []).map(opp => ({ ...opp, pipelineId: andriesPipelineId }))
    ];
    
    console.log(`✅ Found ${allOpportunities.length} total opportunities (Altus: ${altusResponse.data.opportunities?.length || 0}, Andries: ${andriesResponse.data.opportunities?.length || 0})`);
    
    // Process each opportunity
    let successCount = 0;
    let errorCount = 0;
    let skippedCount = 0;
    
    for (const opp of allOpportunities) {
      try {
        // Extract attribution data
        const lastAttribution = opp.attributions?.find(attr => attr.isLast) || 
                              (opp.attributions && opp.attributions[opp.attributions.length - 1]);
        
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
        
        // Skip opportunities without campaign tracking (non-ad leads)
        if (!campaignName) {
          skippedCount++;
          if (skippedCount <= 5) {
            console.log(`⏭️  Skipping non-ad opportunity: ${opp.name}`);
          }
          continue;
        }
        
        const assignedTo = opp.assignedTo || 'unassigned';
        const assignedToName = assignedTo === 'unassigned' 
          ? 'Unassigned' 
          : (userIdToName[assignedTo] || opp.assignedToName || assignedTo);
        
        const pipelineName = pipelineIdToName[opp.pipelineId] || '';
        const stageName = stageIdToName[opp.pipelineStageId] || opp.pipelineStageName || '';
        
        // Store as backfilled record
        await storeStageTransition({
          opportunityId: opp.id,
          opportunityName: opp.name || 'Unknown',
          contactId: opp.contact?.id || '',
          pipelineId: opp.pipelineId,
          pipelineName,
          previousStageId: '',  // Unknown for backfill
          previousStageName: '',
          newStageId: opp.pipelineStageId,
          newStageName: stageName,
          campaignName,
          campaignSource,
          campaignMedium,
          adId,
          adName,
          adSetName,
          assignedTo,
          assignedToName,
          monetaryValue: opp.monetaryValue || 0,
          isBackfilled: true  // Mark as backfilled
        });
        
        successCount++;
        
        if (successCount % 10 === 0) {
          console.log(`   ... ${successCount} opportunities backfilled`);
        }
        
      } catch (error) {
        console.error(`❌ Error backfilling opportunity ${opp.id}:`, error.message);
        errorCount++;
      }
    }
    
    console.log('\n✅ Backfill complete!');
    console.log(`   ✅ Successfully backfilled: ${successCount}`);
    console.log(`   ⏭️  Skipped (no campaign): ${skippedCount}`);
    console.log(`   ❌ Errors: ${errorCount}`);
    console.log(`   📊 Total processed: ${allOpportunities.length}`);
    
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Fatal error during backfill:', error);
    console.error(error.stack);
    process.exit(1);
  }
}

// Run the backfill
backfillOpportunityHistory();

