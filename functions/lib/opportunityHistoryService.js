const admin = require('firebase-admin');

// Get Firestore instance (admin.initializeApp() is called in index.js)
const getDb = () => admin.firestore();

/**
 * Stage category mapping - matches stage names to our 5 key categories
 * Updated to prioritize exact matches for better accuracy
 */
const keyStageNames = {
  // Exact matches (case-insensitive)
  exactMatches: {
    'booked appointments': 'bookedAppointments',
    'booked appointment': 'bookedAppointments',
    'call completed': 'callCompleted',
    'no show': 'noShowCancelledDisqualified',
    'deposit received': 'deposits',
    'cash collected': 'cashCollected'
  },
  // Keyword fallbacks
  bookedAppointments: ['booked', 'appointment', 'scheduled'],
  callCompleted: ['call completed', 'contacted', 'responded'],
  noShowCancelledDisqualified: ['no show', 'cancelled', 'disqualified', 'lost', 'reschedule'],
  deposits: ['deposit', 'paid deposit'],
  cashCollected: ['sold', 'purchased', 'cash collected', 'payment received']
};

/**
 * Match a stage name to its category
 * Priority: Exact matches > Keyword matching
 */
function matchStageCategory(stageName) {
  if (!stageName) return 'other';
  const lowerStageName = stageName.toLowerCase().trim();
  
  // Try exact match first
  if (keyStageNames.exactMatches[lowerStageName]) {
    return keyStageNames.exactMatches[lowerStageName];
  }
  
  // Fall back to keyword matching
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
}

/**
 * Store a stage transition in Firestore
 */
async function storeStageTransition(data) {
  const {
    opportunityId,
    opportunityName,
    contactId,
    pipelineId,
    pipelineName,
    previousStageId,
    previousStageName,
    newStageId,
    newStageName,
    campaignName = '',
    campaignSource = '',
    campaignMedium = '',
    adId = '',
    adName = '',
    adSetName = '',
    assignedTo = 'unassigned',
    assignedToName = 'Unassigned',
    monetaryValue = 0,
    isBackfilled = false
  } = data;

  const timestamp = admin.firestore.Timestamp.now();
  const date = timestamp.toDate();
  
  const stageCategory = matchStageCategory(newStageName);
  
  const historyDoc = {
    opportunityId,
    opportunityName,
    contactId,
    pipelineId,
    pipelineName,
    previousStageId: previousStageId || '',
    previousStageName: previousStageName || '',
    newStageId,
    newStageName,
    stageName: newStageName, // For easier querying
    campaignName,
    campaignSource,
    campaignMedium,
    adId,
    adName,
    adSetName,
    // These fields will be populated by the matching function during sync
    facebookAdId: '',
    matchedAdSetId: '',
    matchedAdSetName: '',
    assignedTo,
    assignedToName,
    timestamp,
    monetaryValue,
    stageCategory,
    year: date.getFullYear(),
    month: date.getMonth() + 1,
    week: getWeekNumber(date),
    isBackfilled
  };

  // Document ID: opportunityId_timestamp
  const docId = `${opportunityId}_${timestamp.toMillis()}`;
  
  const db = getDb();
  await db.collection('opportunityStageHistory').doc(docId).set(historyDoc);
  
  console.log(`✅ Stored stage transition: ${opportunityName} → ${newStageName} (${stageCategory})`);
  
  return docId;
}

/**
 * Get cumulative stage metrics for pipelines within a date range
 */
async function getCumulativeStageMetrics(pipelineIds, startDate, endDate) {
  try {
    console.log(`🔍 Querying cumulative metrics for pipelines: ${pipelineIds.join(', ')}`);
    console.log(`📅 Date range: ${startDate} to ${endDate}`);
    
    // Pipeline ID to friendly name mapping
    const pipelineIdToFriendlyName = {
      'AUduOJBB2lxlsEaNmlJz': 'altus',
      'XeAGJWRnUGJ5tuhXam2g': 'andries',
      'pTbNvnrXqJc9u1oxir3q': 'davide'  // Davide's Pipeline - DDM (was Erich Pipeline)
    };
    
    const startTimestamp = admin.firestore.Timestamp.fromDate(new Date(startDate));
    const endTimestamp = admin.firestore.Timestamp.fromDate(new Date(endDate));
    
    const db = getDb();
    let query = db.collection('opportunityStageHistory')
      .where('timestamp', '>=', startTimestamp)
      .where('timestamp', '<=', endTimestamp);
    
    const snapshot = await query.get();
    
    console.log(`📊 Found ${snapshot.size} stage transition records`);
    
    // Track unique opportunities per stage category
    const opportunitiesByStage = {
      total: new Set(),
      bookedAppointments: new Set(),
      callCompleted: new Set(),
      noShowCancelledDisqualified: new Set(),
      deposits: new Set(),
      cashCollected: new Set()
    };
    
    // Track by pipeline
    const byPipeline = {};
    pipelineIds.forEach(pipelineId => {
      byPipeline[pipelineId] = {
        total: new Set(),
        bookedAppointments: new Set(),
        callCompleted: new Set(),
        noShowCancelledDisqualified: new Set(),
        deposits: new Set(),
        cashCollected: new Set(),
        totalMonetaryValue: 0
      };
    });
    
    // Track by sales agent
    const bySalesAgent = {};
    
    // Track by campaign
    const byCampaign = {};
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const { opportunityId, pipelineId, stageCategory, assignedTo, assignedToName, 
              campaignName, campaignSource, campaignMedium, adId, adName, monetaryValue, timestamp } = data;
      
      // Filter by pipeline if specified
      if (pipelineIds.length > 0 && !pipelineIds.includes(pipelineId)) {
        return;
      }
      
      // Track overall totals
      opportunitiesByStage.total.add(opportunityId);
      if (stageCategory && stageCategory !== 'other') {
        opportunitiesByStage[stageCategory].add(opportunityId);
      }
      
      // Track by pipeline
      if (byPipeline[pipelineId]) {
        byPipeline[pipelineId].total.add(opportunityId);
        if (stageCategory && stageCategory !== 'other') {
          byPipeline[pipelineId][stageCategory].add(opportunityId);
        }
        if (stageCategory === 'cashCollected') {
          byPipeline[pipelineId].totalMonetaryValue += monetaryValue || 0;
        }
      }
      
      // Track by sales agent
      if (assignedTo && assignedTo !== 'unassigned') {
        if (!bySalesAgent[assignedTo]) {
          bySalesAgent[assignedTo] = {
            agentId: assignedTo,
            agentName: assignedToName,
            total: new Set(),
            bookedAppointments: new Set(),
            callCompleted: new Set(),
            noShowCancelledDisqualified: new Set(),
            deposits: new Set(),
            cashCollected: new Set(),
            totalMonetaryValue: 0,
            byPipeline: {}
          };
        }
        
        bySalesAgent[assignedTo].total.add(opportunityId);
        if (stageCategory && stageCategory !== 'other') {
          bySalesAgent[assignedTo][stageCategory].add(opportunityId);
        }
        if (stageCategory === 'cashCollected') {
          bySalesAgent[assignedTo].totalMonetaryValue += monetaryValue || 0;
        }
        
        // Track agent stats by pipeline
        if (!bySalesAgent[assignedTo].byPipeline[pipelineId]) {
          bySalesAgent[assignedTo].byPipeline[pipelineId] = {
            total: new Set(),
            bookedAppointments: new Set(),
            callCompleted: new Set(),
            noShowCancelledDisqualified: new Set(),
            deposits: new Set(),
            cashCollected: new Set(),
            totalMonetaryValue: 0
          };
        }
        
        const agentPipeline = bySalesAgent[assignedTo].byPipeline[pipelineId];
        agentPipeline.total.add(opportunityId);
        if (stageCategory && stageCategory !== 'other') {
          agentPipeline[stageCategory].add(opportunityId);
        }
        if (stageCategory === 'cashCollected') {
          agentPipeline.totalMonetaryValue += monetaryValue || 0;
        }
      }
      
      // Track by campaign (only if has campaign attribution)
      if (campaignName) {
        const campaignKey = `${campaignName}|${campaignSource}|${campaignMedium}`;
        
        if (!byCampaign[campaignKey]) {
          byCampaign[campaignKey] = {
            campaignName,
            campaignSource,
            campaignMedium,
            total: new Set(),
            bookedAppointments: new Set(),
            callCompleted: new Set(),
            noShowCancelledDisqualified: new Set(),
            deposits: new Set(),
            cashCollected: new Set(),
            totalMonetaryValue: 0,
            mostRecentTimestamp: null,
            ads: {}
          };
        }
        
        const campaign = byCampaign[campaignKey];
        campaign.total.add(opportunityId);
        if (stageCategory && stageCategory !== 'other') {
          campaign[stageCategory].add(opportunityId);
        }
        if (stageCategory === 'cashCollected') {
          campaign.totalMonetaryValue += monetaryValue || 0;
        }
        
        // Track most recent timestamp
        if (timestamp) {
          const timestampDate = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
          if (!campaign.mostRecentTimestamp || timestampDate > campaign.mostRecentTimestamp) {
            campaign.mostRecentTimestamp = timestampDate;
          }
        }
        
        // Track by ad
        if (adId) {
          const adKey = `${campaignKey}|${adId}`;
          
          if (!campaign.ads[adKey]) {
            campaign.ads[adKey] = {
              adId,
              adName,
              total: new Set(),
              bookedAppointments: new Set(),
              callCompleted: new Set(),
              noShowCancelledDisqualified: new Set(),
              deposits: new Set(),
              cashCollected: new Set(),
              totalMonetaryValue: 0,
              mostRecentTimestamp: null
            };
          }
          
          const ad = campaign.ads[adKey];
          ad.total.add(opportunityId);
          if (stageCategory && stageCategory !== 'other') {
            ad[stageCategory].add(opportunityId);
          }
          if (stageCategory === 'cashCollected') {
            ad.totalMonetaryValue += monetaryValue || 0;
          }
          
          // Track most recent timestamp for ad
          if (timestamp) {
            const timestampDate = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
            if (!ad.mostRecentTimestamp || timestampDate > ad.mostRecentTimestamp) {
              ad.mostRecentTimestamp = timestampDate;
            }
          }
        }
      }
    });
    
    // Convert Sets to counts
    const convertSetsToCount = (obj) => {
      const result = {};
      for (const key in obj) {
        if (obj[key] instanceof Set) {
          result[key] = obj[key].size;
        } else if (typeof obj[key] === 'object') {
          result[key] = convertSetsToCount(obj[key]);
        } else {
          result[key] = obj[key];
        }
      }
      return result;
    };
    
    const overview = {
      totalOpportunities: opportunitiesByStage.total.size,
      bookedAppointments: opportunitiesByStage.bookedAppointments.size,
      callCompleted: opportunitiesByStage.callCompleted.size,
      noShowCancelledDisqualified: opportunitiesByStage.noShowCancelledDisqualified.size,
      deposits: opportunitiesByStage.deposits.size,
      cashCollected: opportunitiesByStage.cashCollected.size
    };
    
    // Convert pipeline data (use friendly names as keys)
    const pipelinesData = {};
    for (const pipelineId in byPipeline) {
      // Convert pipeline ID to friendly name (e.g., 'XeAGJWRnUGJ5tuhXam2g' -> 'andries')
      const friendlyName = pipelineIdToFriendlyName[pipelineId] || pipelineId;
      
      pipelinesData[friendlyName] = {
        pipelineId: pipelineId,  // Include original ID for reference
        totalOpportunities: byPipeline[pipelineId].total.size,
        bookedAppointments: byPipeline[pipelineId].bookedAppointments.size,
        callCompleted: byPipeline[pipelineId].callCompleted.size,
        noShowCancelledDisqualified: byPipeline[pipelineId].noShowCancelledDisqualified.size,
        deposits: byPipeline[pipelineId].deposits.size,
        cashCollected: byPipeline[pipelineId].cashCollected.size,
        totalMonetaryValue: byPipeline[pipelineId].totalMonetaryValue
      };
      
      console.log(`📊 Pipeline ${friendlyName}: ${byPipeline[pipelineId].total.size} opportunities, ${byPipeline[pipelineId].bookedAppointments.size} booked`);
    }
    
    // Convert agent data
    const salesAgentsList = Object.values(bySalesAgent).map(agent => {
      const byPipelineConverted = convertSetsToCount(agent.byPipeline);
      
      // Create pipelines object with friendly names for frontend consumption
      const pipelines = {};
      for (const pipelineId in byPipelineConverted) {
        const friendlyName = pipelineIdToFriendlyName[pipelineId];
        if (friendlyName) {
          // Map the field names to match what the frontend expects
          const pipelineData = byPipelineConverted[pipelineId];
          pipelines[friendlyName] = {
            totalOpportunities: pipelineData.total, // Rename 'total' to 'totalOpportunities'
            bookedAppointments: pipelineData.bookedAppointments,
            callCompleted: pipelineData.callCompleted,
            noShowCancelledDisqualified: pipelineData.noShowCancelledDisqualified,
            deposits: pipelineData.deposits,
            cashCollected: pipelineData.cashCollected,
            totalMonetaryValue: pipelineData.totalMonetaryValue || 0
          };
        }
      }
      
      const agentData = {
        agentId: agent.agentId,
        agentName: agent.agentName,
        totalOpportunities: agent.total.size,
        bookedAppointments: agent.bookedAppointments.size,
        callCompleted: agent.callCompleted.size,
        noShowCancelledDisqualified: agent.noShowCancelledDisqualified.size,
        deposits: agent.deposits.size,
        cashCollected: agent.cashCollected.size,
        totalMonetaryValue: agent.totalMonetaryValue,
        byPipeline: byPipelineConverted, // Keep for backward compatibility
        pipelines: pipelines // Add friendly name mapping for frontend
      };
      
      // Log detailed agent data for debugging
      console.log(`👤 Agent: ${agent.agentName}`);
      console.log(`   Total Opportunities: ${agent.total.size}`);
      console.log(`   Booked Appointments: ${agent.bookedAppointments.size}`);
      console.log(`   Call Completed: ${agent.callCompleted.size}`);
      console.log(`   No Show/Cancelled/Disqualified: ${agent.noShowCancelledDisqualified.size}`);
      console.log(`   Deposits: ${agent.deposits.size}`);
      console.log(`   Cash Collected: ${agent.cashCollected.size}`);
      console.log(`   Pipelines:`, JSON.stringify(pipelines, null, 2));
      
      return agentData;
    });
    
    // Convert campaign data
    const campaignsList = Object.values(byCampaign).map(campaign => {
      const adsList = Object.values(campaign.ads).map(ad => ({
        adId: ad.adId,
        adName: ad.adName,
        totalOpportunities: ad.total.size,
        bookedAppointments: ad.bookedAppointments.size,
        callCompleted: ad.callCompleted.size,
        noShowCancelledDisqualified: ad.noShowCancelledDisqualified.size,
        deposits: ad.deposits.size,
        cashCollected: ad.cashCollected.size,
        totalMonetaryValue: ad.totalMonetaryValue,
        mostRecentTimestamp: ad.mostRecentTimestamp ? ad.mostRecentTimestamp.toISOString() : null
      })).sort((a, b) => {
        // Sort ads by most recent first
        if (!a.mostRecentTimestamp && !b.mostRecentTimestamp) return 0;
        if (!a.mostRecentTimestamp) return 1;
        if (!b.mostRecentTimestamp) return -1;
        return new Date(b.mostRecentTimestamp) - new Date(a.mostRecentTimestamp);
      });
      
      return {
        campaignName: campaign.campaignName,
        campaignSource: campaign.campaignSource,
        campaignMedium: campaign.campaignMedium,
        campaignKey: `${campaign.campaignName}|${campaign.campaignSource}|${campaign.campaignMedium}`,
        totalOpportunities: campaign.total.size,
        bookedAppointments: campaign.bookedAppointments.size,
        callCompleted: campaign.callCompleted.size,
        noShowCancelledDisqualified: campaign.noShowCancelledDisqualified.size,
        deposits: campaign.deposits.size,
        cashCollected: campaign.cashCollected.size,
        totalMonetaryValue: campaign.totalMonetaryValue,
        mostRecentTimestamp: campaign.mostRecentTimestamp ? campaign.mostRecentTimestamp.toISOString() : null,
        adsList
      };
    }).sort((a, b) => {
      // Sort campaigns by most recent first
      if (!a.mostRecentTimestamp && !b.mostRecentTimestamp) return 0;
      if (!a.mostRecentTimestamp) return 1;
      if (!b.mostRecentTimestamp) return -1;
      return new Date(b.mostRecentTimestamp) - new Date(a.mostRecentTimestamp);
    });
    
    console.log(`✅ Cumulative metrics calculated: ${overview.totalOpportunities} total opportunities`);
    
    return {
      overview,
      byPipeline: pipelinesData,
      salesAgentsList,
      campaignsList
    };
    
  } catch (error) {
    console.error('❌ Error calculating cumulative metrics:', error);
    throw error;
  }
}

/**
 * Get ISO week number
 */
function getWeekNumber(date) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil((((d - yearStart) / 86400000) + 1) / 7);
}

/**
 * Sync opportunities from GoHighLevel API to Firestore
 * @param {Array} opportunities - Array of opportunity objects from GHL API
 * @param {Object} pipelineStages - Map of pipeline IDs to their stages
 * @param {Object} users - Map of user IDs to user details
 * @returns {Object} - Sync statistics
 */
async function syncOpportunitiesFromAPI(opportunities, pipelineStages, users) {
  const stats = {
    synced: 0,
    skipped: 0,
    errors: 0,
    details: []
  };

  const db = getDb();

  for (const opportunity of opportunities) {
    try {
      const opportunityId = opportunity.id;
      const opportunityName = opportunity.name || 'Unnamed Opportunity';
      const contactId = opportunity.contact?.id || '';
      const pipelineId = opportunity.pipelineId || '';
      const currentStageId = opportunity.pipelineStageId || opportunity.stageId || '';

      // Extract campaign attribution (optional - for advert performance tracking)
      const lastAttribution = opportunity.attributions?.find(attr => attr.isLast) ||
                            (opportunity.attributions && opportunity.attributions[opportunity.attributions.length - 1]);
      
      const campaignName = lastAttribution?.utmCampaign || '';
      
      // NOTE: We no longer skip opportunities without campaign data
      // Sales Performance tracking needs ALL opportunities (with or without UTM tracking)
      // Advert Performance filtering happens at the analytics query level

      // Get stage details
      const pipeline = pipelineStages[pipelineId];
      const pipelineName = pipeline?.name || 'Unknown Pipeline';
      const currentStage = pipeline?.stages?.find(s => s.id === currentStageId);
      const currentStageName = currentStage?.name || opportunity.pipelineStageName || 'Unknown Stage';

      // Check if we already have this opportunity at this stage
      const existingQuery = await db.collection('opportunityStageHistory')
        .where('opportunityId', '==', opportunityId)
        .orderBy('timestamp', 'desc')
        .limit(1)
        .get();

      let shouldStore = false;
      let previousStageId = '';
      let previousStageName = '';

      if (existingQuery.empty) {
        // New opportunity - store it
        shouldStore = true;
      } else {
        // Check if stage has changed
        const lastKnownDoc = existingQuery.docs[0];
        const lastKnownData = lastKnownDoc.data();
        
        if (lastKnownData.newStageId !== currentStageId) {
          // Stage has changed
          shouldStore = true;
          previousStageId = lastKnownData.newStageId;
          previousStageName = lastKnownData.newStageName;
        }
      }

      if (shouldStore) {
        // Get campaign and agent info
        const campaignSource = lastAttribution?.utmSource || '';
        const campaignMedium = lastAttribution?.utmMedium || '';
        const adId = lastAttribution?.utmAdId || lastAttribution?.utmContent || '';
        const adName = lastAttribution?.utmContent || adId;
        const adSetName = lastAttribution?.utmAdset || lastAttribution?.adset || '';
        
        const assignedTo = opportunity.assignedTo || 'unassigned';
        const assignedToName = users[assignedTo]?.name || users[assignedTo]?.email || assignedTo;

        await storeStageTransition({
          opportunityId,
          opportunityName,
          contactId,
          pipelineId,
          pipelineName,
          previousStageId,
          previousStageName,
          newStageId: currentStageId,
          newStageName: currentStageName,
          campaignName,
          campaignSource,
          campaignMedium,
          adId,
          adName,
          adSetName,
          assignedTo,
          assignedToName,
          monetaryValue: opportunity.monetaryValue || 0,
          isBackfilled: false
        });

        stats.synced++;
        stats.details.push({
          opportunityId,
          opportunityName,
          action: existingQuery.empty ? 'created' : 'updated',
          stage: currentStageName
        });
      } else {
        stats.skipped++;
      }

    } catch (error) {
      console.error(`❌ Error syncing opportunity ${opportunity.id}:`, error.message);
      stats.errors++;
      stats.details.push({
        opportunityId: opportunity.id,
        error: error.message
      });
    }
  }

  console.log(`📊 Sync complete: ${stats.synced} synced, ${stats.skipped} skipped, ${stats.errors} errors`);

  // After syncing opportunities, match them to Facebook ads
  try {
    await matchAndUpdateGHLDataToFacebookAds();
  } catch (error) {
    console.error('⚠️ Error matching GHL data to Facebook ads:', error.message);
    // Don't fail the whole sync if matching fails
  }

  return stats;
}

/**
 * Normalize ad/campaign name for matching
 * Removes special characters, converts to lowercase, normalizes whitespace
 */
function normalizeAdName(name) {
  if (!name) return '';
  return name
    .toLowerCase()
    .replace(/[^\w\s]/g, '') // Remove special characters
    .replace(/\s+/g, ' ')    // Normalize whitespace
    .trim();
}

/**
 * Match GHL opportunities to Facebook ads and update adPerformance collection
 * This function aggregates GHL metrics (leads, bookings, deposits, cash) and updates
 * the ghlStats field in each Facebook ad's document
 * 
 * NOTE: Stores COUNTS for deposits/cash. Monetary amounts are calculated on frontend
 * using Product configuration (default R1500 per deposit)
 */
async function matchAndUpdateGHLDataToFacebookAds() {
  console.log('🔄 Matching GHL data to Facebook ads...');

  const db = getDb();
  
  try {
    // Get all Facebook ads from adPerformance collection
    const adPerformanceSnapshot = await db.collection('adPerformance').get();
    
    if (adPerformanceSnapshot.empty) {
      console.log('⚠️ No Facebook ads found in adPerformance collection. Run Facebook sync first.');
      return { matched: 0, unmatched: 0 };
    }

    // Load default deposit amount from Product configuration
    let defaultDepositAmount = 1500; // Default R1500
    try {
      const productsSnapshot = await db.collection('products').limit(1).get();
      if (!productsSnapshot.empty) {
        const productData = productsSnapshot.docs[0].data();
        defaultDepositAmount = productData.depositAmount || 1500;
        console.log(`📦 Using default deposit amount from Product: R${defaultDepositAmount}`);
      }
    } catch (error) {
      console.log(`⚠️ Could not load Product config, using default R${defaultDepositAmount}`);
    }

    const stats = {
      matched: 0,
      unmatched: 0,
      errors: 0
    };

    // Process each Facebook ad
    for (const adDoc of adPerformanceSnapshot.docs) {
      try {
        const adData = adDoc.data();
        const adId = adDoc.id;
        const adName = adData.adName || '';
        const campaignName = adData.campaignName || '';
        const adSetName = adData.adSetName || '';

        // Normalize names for matching
        const normalizedAdName = normalizeAdName(adName);
        const normalizedCampaignName = normalizeAdName(campaignName);
        const normalizedAdSetName = normalizeAdName(adSetName);

        // Query opportunities that match this ad
        // Match by: campaign name AND (ad name OR ad set name)
        const historyQuery = await db.collection('opportunityStageHistory')
          .where('campaignName', '==', campaignName)
          .get();

        // Filter opportunities using improved composite matching
        const matchingOpportunities = [];
        console.log(`🔍 Matching ad: ${adName} (ID: ${adId}) in ad set: ${adSetName}`);
        
        for (const oppDoc of historyQuery.docs) {
          const oppData = oppDoc.data();
          const oppAdName = normalizeAdName(oppData.adName || '');
          const oppAdSetName = normalizeAdName(oppData.adSetName || '');
          
          // Priority 1: Match by Facebook Ad ID if available (most accurate)
          if (oppData.facebookAdId && oppData.facebookAdId === adId) {
            matchingOpportunities.push({ ...oppData, docId: oppDoc.id });
            continue;
          }
          
          // Priority 2: Match by Campaign + Ad Set + Ad Name (composite matching)
          if (oppAdName === normalizedAdName) {
            // If we have ad set info from both sides, require it to match
            if (normalizedAdSetName && oppAdSetName) {
              if (oppAdSetName === normalizedAdSetName) {
                matchingOpportunities.push({ ...oppData, docId: oppDoc.id });
              }
            } else {
              // Fallback: match by ad name only (backward compatibility for old data)
              // This handles opportunities captured before ad set tracking was added
              matchingOpportunities.push({ ...oppData, docId: oppDoc.id });
            }
          }
        }
        
        console.log(`   Found ${matchingOpportunities.length} matching opportunities`);
        if (matchingOpportunities.length > 0) {
          console.log(`   Matched IDs: ${matchingOpportunities.map(o => o.opportunityId).join(', ')}`);
        }

        // Aggregate GHL metrics from matching opportunities
        const ghlMetrics = {
          leads: 0,
          bookings: 0,
          deposits: 0,
          cashCollected: 0,  // Count of opportunities in cash collected stage
          cashAmount: 0       // Total cash amount (deposits + cash collected)
        };

        // Track unique opportunities and their latest stage
        const opportunityLatestState = new Map();

        // First pass: Find the latest state for each unique opportunity
        for (const opp of matchingOpportunities) {
          const oppId = opp.opportunityId;
          const oppTimestamp = opp.timestamp?.toDate?.() || new Date(opp.timestamp);
          
          if (!opportunityLatestState.has(oppId) || 
              oppTimestamp > opportunityLatestState.get(oppId).timestamp) {
            opportunityLatestState.set(oppId, {
              stageCategory: opp.stageCategory,
              stageName: opp.newStageName,
              timestamp: oppTimestamp,
              monetaryValue: opp.monetaryValue || 0
            });
          }
        }

        // Second pass: Count opportunities and calculate cash amounts
        for (const [oppId, state] of opportunityLatestState) {
          ghlMetrics.leads++; // Count each unique opportunity as a lead

          // Count by stage category
          if (state.stageCategory === 'bookedAppointments') {
            ghlMetrics.bookings++;
          }
          if (state.stageCategory === 'deposits') {
            ghlMetrics.deposits++;
            // Use monetaryValue if exists, otherwise use default deposit amount
            const depositValue = state.monetaryValue > 0 ? state.monetaryValue : defaultDepositAmount;
            ghlMetrics.cashAmount += depositValue;
          }
          if (state.stageCategory === 'cashCollected') {
            ghlMetrics.cashCollected++;
            // Use monetaryValue if exists, otherwise use default deposit amount
            const cashValue = state.monetaryValue > 0 ? state.monetaryValue : defaultDepositAmount;
            ghlMetrics.cashAmount += cashValue;
          }
        }

        // Update ad performance document with GHL stats
        const updateData = {
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        };

        if (ghlMetrics.leads > 0) {
          // Has GHL data - mark as matched
          updateData.ghlStats = {
            campaignKey: campaignName,
            leads: ghlMetrics.leads,
            bookings: ghlMetrics.bookings,
            deposits: ghlMetrics.deposits,
            cashCollected: ghlMetrics.cashCollected,
            cashAmount: ghlMetrics.cashAmount,
            lastSync: admin.firestore.FieldValue.serverTimestamp()
          };
          updateData.matchingStatus = 'matched';
          stats.matched++;

          console.log(`✅ Matched: ${adName} → ${ghlMetrics.leads} leads, ${ghlMetrics.bookings} bookings, ${ghlMetrics.deposits} deposits, ${ghlMetrics.cashCollected} cash (R${ghlMetrics.cashAmount.toFixed(2)})`);
          
          // Back-populate Facebook Ad ID into opportunity history for future accurate matching
          const backPopulatePromises = [];
          for (const opp of matchingOpportunities) {
            // Only update if the opportunity doesn't already have the correct Facebook Ad ID
            if (!opp.facebookAdId || opp.facebookAdId !== adId) {
              const updatePromise = db.collection('opportunityStageHistory').doc(opp.docId).update({
                facebookAdId: adId,
                matchedAdSetId: adSetId || '',
                matchedAdSetName: adSetName || '',
                lastMatched: admin.firestore.FieldValue.serverTimestamp()
              }).catch(err => {
                console.error(`⚠️  Failed to back-populate ad ID for opportunity ${opp.opportunityId}:`, err.message);
              });
              backPopulatePromises.push(updatePromise);
            }
          }
          
          // Execute all back-population updates in parallel
          if (backPopulatePromises.length > 0) {
            await Promise.all(backPopulatePromises);
            console.log(`   📝 Back-populated Facebook Ad ID to ${backPopulatePromises.length} opportunities`);
          }
        } else {
          // No GHL data - remains unmatched
          updateData.matchingStatus = 'unmatched';
          // Clear any old GHL stats
          updateData.ghlStats = admin.firestore.FieldValue.delete();
          stats.unmatched++;
        }

        await db.collection('adPerformance').doc(adId).update(updateData);

      } catch (error) {
        console.error(`❌ Error matching ad ${adDoc.id}:`, error.message);
        stats.errors++;
      }
    }

    console.log(`✅ GHL matching complete: ${stats.matched} matched, ${stats.unmatched} unmatched, ${stats.errors} errors`);
    return stats;

  } catch (error) {
    console.error('❌ Error in matchAndUpdateGHLDataToFacebookAds:', error);
    throw error;
  }
}

module.exports = {
  storeStageTransition,
  getCumulativeStageMetrics,
  matchStageCategory,
  syncOpportunitiesFromAPI,
  matchAndUpdateGHLDataToFacebookAds,
  normalizeAdName
};

