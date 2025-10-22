const admin = require('firebase-admin');

// Get Firestore instance (admin.initializeApp() is called in index.js)
const getDb = () => admin.firestore();

/**
 * Stage category mapping - matches stage names to our 5 key categories
 */
const keyStageNames = {
  bookedAppointments: ['booked', 'appointment', 'scheduled'],
  callCompleted: ['call completed', 'contacted', 'responded'],
  noShowCancelledDisqualified: ['no show', 'cancelled', 'disqualified', 'lost', 'reschedule'],
  deposits: ['deposit', 'paid deposit'],
  cashCollected: ['sold', 'purchased', 'cash collected', 'payment received']
};

/**
 * Match a stage name to its category
 */
function matchStageCategory(stageName) {
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
    campaignName,
    campaignSource,
    campaignMedium,
    adId,
    adName,
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
    
    // Convert pipeline data
    const pipelinesData = {};
    for (const pipelineId in byPipeline) {
      pipelinesData[pipelineId] = {
        totalOpportunities: byPipeline[pipelineId].total.size,
        bookedAppointments: byPipeline[pipelineId].bookedAppointments.size,
        callCompleted: byPipeline[pipelineId].callCompleted.size,
        noShowCancelledDisqualified: byPipeline[pipelineId].noShowCancelledDisqualified.size,
        deposits: byPipeline[pipelineId].deposits.size,
        cashCollected: byPipeline[pipelineId].cashCollected.size,
        totalMonetaryValue: byPipeline[pipelineId].totalMonetaryValue
      };
    }
    
    // Convert agent data
    const salesAgentsList = Object.values(bySalesAgent).map(agent => ({
      agentId: agent.agentId,
      agentName: agent.agentName,
      totalOpportunities: agent.total.size,
      bookedAppointments: agent.bookedAppointments.size,
      callCompleted: agent.callCompleted.size,
      noShowCancelledDisqualified: agent.noShowCancelledDisqualified.size,
      deposits: agent.deposits.size,
      cashCollected: agent.cashCollected.size,
      totalMonetaryValue: agent.totalMonetaryValue,
      byPipeline: convertSetsToCount(agent.byPipeline)
    }));
    
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

      // Skip if no campaign attribution
      const lastAttribution = opportunity.attributions?.find(attr => attr.isLast) ||
                            (opportunity.attributions && opportunity.attributions[opportunity.attributions.length - 1]);
      
      const campaignName = lastAttribution?.utmCampaign || '';
      
      if (!campaignName) {
        stats.skipped++;
        continue; // Skip opportunities without campaign data
      }

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

  return stats;
}

module.exports = {
  storeStageTransition,
  getCumulativeStageMetrics,
  matchStageCategory,
  syncOpportunitiesFromAPI
};

