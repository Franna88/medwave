/**
 * Scheduled Aggregation Service
 * 
 * Runs periodically to re-aggregate all campaigns and verify data consistency.
 * Acts as a safety net to catch any missed updates from real-time triggers.
 */

const admin = require('firebase-admin');
const { aggregateCampaignTotals } = require('./campaignAggregation');
const { aggregateAdSetTotals } = require('./adSetAggregation');
const { verifyMappingIntegrity } = require('./opportunityMappingService');

/**
 * Re-aggregate all campaigns
 * @returns {Promise<Object>} Summary of aggregation results
 */
async function reAggregateAllCampaigns() {
  const db = admin.firestore();
  
  console.log('🔄 Starting scheduled re-aggregation of all campaigns...');
  
  try {
    // Get all campaigns
    const campaignsSnapshot = await db.collection('campaigns').get();
    
    if (campaignsSnapshot.empty) {
      console.log('   No campaigns found');
      return {
        success: true,
        campaignsProcessed: 0,
        errors: 0
      };
    }
    
    let successCount = 0;
    let errorCount = 0;
    const errors = [];
    
    // Re-aggregate each campaign
    for (const campaignDoc of campaignsSnapshot.docs) {
      try {
        await aggregateCampaignTotals(campaignDoc.id);
        successCount++;
      } catch (error) {
        console.error(`   ⚠️ Error re-aggregating campaign ${campaignDoc.id}:`, error.message);
        errorCount++;
        errors.push({
          campaignId: campaignDoc.id,
          error: error.message
        });
      }
    }
    
    console.log(`✅ Re-aggregation complete: ${successCount} campaigns processed, ${errorCount} errors`);
    
    return {
      success: true,
      campaignsProcessed: successCount,
      errors: errorCount,
      errorDetails: errors
    };
    
  } catch (error) {
    console.error('❌ Error in scheduled re-aggregation:', error);
    throw error;
  }
}

/**
 * Re-aggregate all ad sets
 * @returns {Promise<Object>} Summary of aggregation results
 */
async function reAggregateAllAdSets() {
  const db = admin.firestore();
  
  console.log('🔄 Starting scheduled re-aggregation of all ad sets...');
  
  try {
    // Get all ad sets
    const adSetsSnapshot = await db.collection('adSets').get();
    
    if (adSetsSnapshot.empty) {
      console.log('   No ad sets found');
      return {
        success: true,
        adSetsProcessed: 0,
        errors: 0
      };
    }
    
    let successCount = 0;
    let errorCount = 0;
    const errors = [];
    
    // Re-aggregate each ad set
    for (const adSetDoc of adSetsSnapshot.docs) {
      try {
        await aggregateAdSetTotals(adSetDoc.id);
        successCount++;
      } catch (error) {
        console.error(`   ⚠️ Error re-aggregating ad set ${adSetDoc.id}:`, error.message);
        errorCount++;
        errors.push({
          adSetId: adSetDoc.id,
          error: error.message
        });
      }
    }
    
    console.log(`✅ Re-aggregation complete: ${successCount} ad sets processed, ${errorCount} errors`);
    
    return {
      success: true,
      adSetsProcessed: successCount,
      errors: errorCount,
      errorDetails: errors
    };
    
  } catch (error) {
    console.error('❌ Error in scheduled re-aggregation:', error);
    throw error;
  }
}

/**
 * Verify data consistency across collections
 * @returns {Promise<Object>} Verification results
 */
async function verifyDataConsistency() {
  const db = admin.firestore();
  
  console.log('🔍 Verifying data consistency...');
  
  try {
    const issues = [];
    
    // 1. Check for orphaned ads (ads without campaigns)
    const adsSnapshot = await db.collection('ads').get();
    const campaignsSnapshot = await db.collection('campaigns').get();
    const campaignIds = new Set(campaignsSnapshot.docs.map(doc => doc.id));
    
    let orphanedAds = 0;
    adsSnapshot.forEach(adDoc => {
      const ad = adDoc.data();
      if (ad.campaignId && !campaignIds.has(ad.campaignId)) {
        orphanedAds++;
      }
    });
    
    if (orphanedAds > 0) {
      issues.push({
        type: 'orphaned_ads',
        count: orphanedAds,
        severity: 'warning'
      });
    }
    
    // 2. Check for cross-campaign duplicates
    const mappingVerification = await verifyMappingIntegrity();
    
    if (!mappingVerification.success) {
      issues.push({
        type: 'cross_campaign_duplicates',
        count: mappingVerification.duplicates.length,
        severity: 'critical',
        details: mappingVerification.duplicates.slice(0, 10) // First 10
      });
    }
    
    // 3. Check for opportunities without mappings
    const opportunitiesSnapshot = await db.collection('ghlOpportunities').get();
    const mappingsSnapshot = await db.collection('ghlOpportunityMapping').get();
    const mappingIds = new Set(mappingsSnapshot.docs.map(doc => doc.id));
    
    let unmappedOpportunities = 0;
    opportunitiesSnapshot.forEach(oppDoc => {
      if (!mappingIds.has(oppDoc.id)) {
        unmappedOpportunities++;
      }
    });
    
    if (unmappedOpportunities > 0) {
      issues.push({
        type: 'unmapped_opportunities',
        count: unmappedOpportunities,
        severity: 'warning'
      });
    }
    
    console.log(`✅ Consistency check complete: ${issues.length} issues found`);
    
    return {
      success: issues.length === 0,
      issues: issues,
      timestamp: new Date().toISOString()
    };
    
  } catch (error) {
    console.error('❌ Error in consistency verification:', error);
    throw error;
  }
}

/**
 * Main scheduled aggregation function
 * Runs all aggregation and verification tasks
 * @returns {Promise<Object>} Summary of all tasks
 */
async function runScheduledAggregation() {
  console.log('=' * 80);
  console.log('SCHEDULED AGGREGATION - Starting');
  console.log('=' * 80);
  
  const startTime = Date.now();
  const results = {
    startTime: new Date().toISOString(),
    tasks: {}
  };
  
  try {
    // Task 1: Re-aggregate all campaigns
    try {
      results.tasks.campaignAggregation = await reAggregateAllCampaigns();
    } catch (error) {
      results.tasks.campaignAggregation = {
        success: false,
        error: error.message
      };
    }
    
    // Task 2: Re-aggregate all ad sets
    try {
      results.tasks.adSetAggregation = await reAggregateAllAdSets();
    } catch (error) {
      results.tasks.adSetAggregation = {
        success: false,
        error: error.message
      };
    }
    
    // Task 3: Verify data consistency
    try {
      results.tasks.consistencyCheck = await verifyDataConsistency();
    } catch (error) {
      results.tasks.consistencyCheck = {
        success: false,
        error: error.message
      };
    }
    
    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;
    
    results.endTime = new Date().toISOString();
    results.durationSeconds = duration;
    results.success = true;
    
    console.log('=' * 80);
    console.log(`SCHEDULED AGGREGATION - Complete (${duration}s)`);
    console.log('=' * 80);
    
    // Log results to Firestore for monitoring
    const db = admin.firestore();
    await db.collection('scheduledAggregationLogs').add({
      ...results,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return results;
    
  } catch (error) {
    console.error('❌ Scheduled aggregation failed:', error);
    
    results.success = false;
    results.error = error.message;
    results.endTime = new Date().toISOString();
    
    return results;
  }
}

/**
 * Cloud Function trigger: Scheduled aggregation (runs every 6 hours)
 */
async function scheduledAggregationTrigger(context) {
  console.log('⏰ Scheduled aggregation triggered');
  
  try {
    const results = await runScheduledAggregation();
    return results;
  } catch (error) {
    console.error('Error in scheduled aggregation trigger:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

module.exports = {
  runScheduledAggregation,
  reAggregateAllCampaigns,
  reAggregateAllAdSets,
  verifyDataConsistency,
  scheduledAggregationTrigger
};

