#!/usr/bin/env node
/**
 * Sync GHL Opportunities to AdvertData Collection
 * 
 * ⚠️ CRITICAL: Fetches data ONLY from GHL API (NOT from Firebase collections)
 * Extracts ALL 5 UTM parameters: h_ad_id, utm_source, utm_medium, utm_campaign, fbc_id
 * 
 * Usage: node functions/syncGHLToAdvertData.js [--dry-run]
 */

const admin = require('firebase-admin');
const axios = require('axios');
const serviceAccount = require('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json');
const { calculateWeekIdFromTimestamp } = require('./lib/advertDataSync');

// Initialize Firebase Admin
try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  // Already initialized
}

const db = admin.firestore();

// GHL API Configuration
const GHL_BASE_URL = 'https://services.leadconnectorhq.com';
const GHL_API_KEY = process.env.GHL_API_KEY || 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a';
const GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw';

// Check for dry-run flag
const DRY_RUN = process.argv.includes('--dry-run');

/**
 * Get GHL API headers
 */
function getGHLHeaders() {
  return {
    'Authorization': `Bearer ${GHL_API_KEY}`,
    'Version': '2021-07-28',
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  };
}

/**
 * Extract ALL 5 UTM parameters from opportunity attribution
 * 
 * UTM Structure:
 * - utm_source={{campaign.name}}
 * - utm_medium={{adset.name}}
 * - utm_campaign={{ad.name}}
 * - fbc_id={{adset.id}}
 * - h_ad_id={{ad.id}}
 */
function extractUTMParams(opportunity) {
  const attributions = opportunity.attributions || [];
  
  if (attributions.length === 0) {
    return null;
  }
  
  // Get last attribution
  const lastAttribution = attributions.find(attr => attr.isLast) || 
                         attributions[attributions.length - 1];
  
  if (!lastAttribution) {
    return null;
  }
  
  // Extract ALL 5 UTM parameters
  const utmData = {
    // PRIMARY: Facebook Ad ID (h_ad_id) - used for matching
    facebookAdId: lastAttribution.h_ad_id || lastAttribution.hAdId || '',
    
    // Campaign Name (utm_source)
    campaignName: lastAttribution.utmSource || '',
    
    // Ad Set Name (utm_medium)
    adSetName: lastAttribution.utmMedium || '',
    
    // Ad Name (utm_campaign)
    adName: lastAttribution.utmCampaign || '',
    
    // Ad Set ID (fbc_id)
    adSetId: lastAttribution.fbc_id || lastAttribution.fbcId || '',
    
    // Additional tracking
    fbclid: lastAttribution.fbclid || '',
    gclid: lastAttribution.gclid || ''
  };
  
  return utmData;
}

/**
 * Get stage category from stage name
 */
function getStageCategory(stageName) {
  if (!stageName) return 'other';
  
  const stage = stageName.toLowerCase();
  
  if (stage.includes('appointment') || stage.includes('booked')) {
    return 'bookedAppointments';
  }
  if (stage.includes('deposit')) {
    return 'deposits';
  }
  if (stage.includes('cash') && stage.includes('collected')) {
    return 'cashCollected';
  }
  
  return 'other';
}

/**
 * Fetch ALL opportunities from GHL API with pagination
 * Returns opportunities from last 2 months (October and November)
 */
async function fetchAllOpportunitiesFromGHL() {
  console.log('📋 Fetching ALL opportunities from GHL API...');
  console.log('   ⚠️  Data source: GHL API ONLY (not Firebase)');
  console.log('   📅 Date range: Last 2 months (October & November 2025)');
  console.log('');
  
  const allOpportunities = [];
  let page = 1;
  const limit = 100;
  let hasMore = true;
  
  // Calculate 2 months ago
  const twoMonthsAgo = new Date();
  twoMonthsAgo.setMonth(twoMonthsAgo.getMonth() - 2);
  
  while (hasMore) {
    try {
      console.log(`   Fetching page ${page}...`);
      
      const response = await axios.get(
        `${GHL_BASE_URL}/opportunities/search`,
        {
          headers: getGHLHeaders(),
          params: {
            location_id: GHL_LOCATION_ID,
            limit: limit,
            page: page
          },
          timeout: 30000
        }
      );
      
      const opportunities = response.data.opportunities || [];
      
      if (opportunities.length === 0) {
        hasMore = false;
        break;
      }
      
      // Filter to last 2 months
      const recentOpportunities = opportunities.filter(opp => {
        const createdAt = new Date(opp.createdAt || opp.dateAdded);
        return createdAt >= twoMonthsAgo;
      });
      
      allOpportunities.push(...recentOpportunities);
      
      console.log(`   ✓ Page ${page}: ${opportunities.length} opportunities (${recentOpportunities.length} in last 2 months)`);
      
      // Check if we got fewer results than limit (last page)
      if (opportunities.length < limit) {
        hasMore = false;
      }
      
      page++;
      
      // Rate limiting: 500ms delay between requests
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.error(`   ❌ Error fetching page ${page}:`, error.message);
      hasMore = false;
    }
  }
  
  console.log('');
  console.log(`✅ Total opportunities fetched: ${allOpportunities.length}`);
  console.log('');
  
  return allOpportunities;
}

/**
 * Process opportunities and extract UTM data
 */
function processOpportunities(opportunities) {
  console.log('🔍 Processing opportunities and extracting UTM parameters...');
  console.log('');
  
  const stats = {
    total: opportunities.length,
    withHAdId: 0,
    withAllUTMParams: 0,
    withoutHAdId: 0,
    utmQuality: {
      hasHAdId: 0,
      hasCampaignName: 0,
      hasAdSetName: 0,
      hasAdName: 0,
      hasAdSetId: 0
    }
  };
  
  const processedData = [];
  const sampleUTMData = [];
  
  let processedCount = 0;
  for (const opp of opportunities) {
    processedCount++;
    
    // Progress update every 100 opportunities
    if (processedCount % 100 === 0) {
      console.log(`   Processing: ${processedCount}/${opportunities.length} opportunities...`);
    }
    
    const utmData = extractUTMParams(opp);
    
    if (!utmData) {
      stats.withoutHAdId++;
      continue;
    }
    
    // Track UTM quality
    if (utmData.facebookAdId) stats.utmQuality.hasHAdId++;
    if (utmData.campaignName) stats.utmQuality.hasCampaignName++;
    if (utmData.adSetName) stats.utmQuality.hasAdSetName++;
    if (utmData.adName) stats.utmQuality.hasAdName++;
    if (utmData.adSetId) stats.utmQuality.hasAdSetId++;
    
    // Only process opportunities with h_ad_id
    if (!utmData.facebookAdId) {
      stats.withoutHAdId++;
      continue;
    }
    
    stats.withHAdId++;
    
    // Check if all 5 UTM params are present
    if (utmData.facebookAdId && utmData.campaignName && utmData.adSetName && 
        utmData.adName && utmData.adSetId) {
      stats.withAllUTMParams++;
    }
    
    // Get stage category
    const stageCategory = getStageCategory(opp.pipelineStageName || opp.status);
    
    // Get monetary value from opportunity
    // Priority:
    // 1. opportunity.monetaryValue (standard GHL field)
    // 2. Custom fields from contact (Contract Value, Cash Collected)
    // 3. Default R1500 for deposits/cash stages
    let monetaryValue = 0;
    
    // First: Check standard opportunity monetaryValue field
    if (opp.monetaryValue && opp.monetaryValue > 0) {
      monetaryValue = parseFloat(opp.monetaryValue);
    }
    
    // Second: Check custom fields if monetaryValue not set
    if (monetaryValue === 0) {
      const customFields = opp.customFields || [];
      for (const field of customFields) {
        const fieldKey = (field.key || field.id || '').toLowerCase();
        const fieldValue = parseFloat(field.value) || 0;
        
        if (fieldKey.includes('contract') || fieldKey.includes('value')) {
          monetaryValue = fieldValue;
          break;
        }
        if (fieldKey.includes('cash') && fieldKey.includes('collected')) {
          monetaryValue = fieldValue;
          break;
        }
      }
    }
    
    // Third: Default to R1500 for deposits/cash stages if still no value
    if (monetaryValue === 0 && (stageCategory === 'deposits' || stageCategory === 'cashCollected')) {
      monetaryValue = 1500;
    }
    
    // Get timestamp
    const timestamp = new Date(opp.createdAt || opp.dateAdded || Date.now());
    
    processedData.push({
      opportunityId: opp.id,
      opportunityName: opp.name || 'Unnamed',
      facebookAdId: utmData.facebookAdId,
      campaignName: utmData.campaignName,
      adSetName: utmData.adSetName,
      adName: utmData.adName,
      adSetId: utmData.adSetId,
      stageCategory,
      stageName: opp.pipelineStageName || opp.status || '',
      monetaryValue,
      timestamp
    });
    
    // Collect sample UTM data (first 5)
    if (sampleUTMData.length < 5) {
      sampleUTMData.push({
        opportunityName: opp.name,
        h_ad_id: utmData.facebookAdId,
        utm_source: utmData.campaignName,
        utm_medium: utmData.adSetName,
        utm_campaign: utmData.adName,
        fbc_id: utmData.adSetId
      });
    }
  }
  
  // Print statistics
  console.log('📊 UTM Extraction Statistics:');
  console.log(`   Total opportunities: ${stats.total}`);
  console.log(`   With h_ad_id: ${stats.withHAdId} (${((stats.withHAdId/stats.total)*100).toFixed(1)}%)`);
  console.log(`   With ALL 5 UTM params: ${stats.withAllUTMParams} (${((stats.withAllUTMParams/stats.total)*100).toFixed(1)}%)`);
  console.log(`   Without h_ad_id (skipped): ${stats.withoutHAdId} (${((stats.withoutHAdId/stats.total)*100).toFixed(1)}%)`);
  console.log('');
  console.log('📊 UTM Parameter Completeness:');
  console.log(`   h_ad_id: ${stats.utmQuality.hasHAdId} (${((stats.utmQuality.hasHAdId/stats.total)*100).toFixed(1)}%)`);
  console.log(`   utm_source (campaign): ${stats.utmQuality.hasCampaignName} (${((stats.utmQuality.hasCampaignName/stats.total)*100).toFixed(1)}%)`);
  console.log(`   utm_medium (ad set): ${stats.utmQuality.hasAdSetName} (${((stats.utmQuality.hasAdSetName/stats.total)*100).toFixed(1)}%)`);
  console.log(`   utm_campaign (ad): ${stats.utmQuality.hasAdName} (${((stats.utmQuality.hasAdName/stats.total)*100).toFixed(1)}%)`);
  console.log(`   fbc_id (ad set ID): ${stats.utmQuality.hasAdSetId} (${((stats.utmQuality.hasAdSetId/stats.total)*100).toFixed(1)}%)`);
  console.log('');
  
  // Show sample UTM data
  if (sampleUTMData.length > 0) {
    console.log('📋 Sample UTM Data (first 5 opportunities):');
    sampleUTMData.forEach((sample, idx) => {
      console.log(`   ${idx + 1}. ${sample.opportunityName}`);
      console.log(`      h_ad_id: ${sample.h_ad_id}`);
      console.log(`      utm_source: ${sample.utm_source}`);
      console.log(`      utm_medium: ${sample.utm_medium}`);
      console.log(`      utm_campaign: ${sample.utm_campaign}`);
      console.log(`      fbc_id: ${sample.fbc_id}`);
      console.log('');
    });
  }
  
  return { processedData, stats };
}

/**
 * Group opportunities by Facebook Ad ID and week
 */
function groupByAdAndWeek(processedData) {
  console.log('📅 Grouping opportunities by ad and week...');
  console.log('');
  
  // Map: adId -> weekId -> { opportunities, metrics }
  const adWeekMap = new Map();
  
  for (const opp of processedData) {
    const adId = opp.facebookAdId;
    const weekId = calculateWeekIdFromTimestamp(opp.timestamp);
    
    if (!adWeekMap.has(adId)) {
      adWeekMap.set(adId, new Map());
    }
    
    const weekMap = adWeekMap.get(adId);
    
    if (!weekMap.has(weekId)) {
      weekMap.set(weekId, {
        opportunities: new Set(), // Track unique opportunity IDs
        leads: 0,
        bookedAppointments: 0,
        deposits: 0,
        cashCollected: 0,
        cashAmount: 0
      });
    }
    
    const weekData = weekMap.get(weekId);
    
    // Only count each opportunity once (avoid duplicates)
    if (!weekData.opportunities.has(opp.opportunityId)) {
      weekData.opportunities.add(opp.opportunityId);
      weekData.leads++;
      
      if (opp.stageCategory === 'bookedAppointments') {
        weekData.bookedAppointments++;
      } else if (opp.stageCategory === 'deposits') {
        weekData.deposits++;
        weekData.cashAmount += opp.monetaryValue;
      } else if (opp.stageCategory === 'cashCollected') {
        weekData.cashCollected++;
        weekData.cashAmount += opp.monetaryValue;
      }
    }
  }
  
  console.log(`✅ Grouped data for ${adWeekMap.size} ads`);
  
  // Calculate total weeks
  let totalWeeks = 0;
  for (const weekMap of adWeekMap.values()) {
    totalWeeks += weekMap.size;
  }
  console.log(`✅ Total weeks to update: ${totalWeeks}`);
  
  // Show sample of what will be written
  console.log('');
  console.log('📋 Sample of grouped data (first 3 ads):');
  let sampleCount = 0;
  for (const [adId, weekMap] of adWeekMap) {
    if (sampleCount >= 3) break;
    console.log(`   Ad ${adId}: ${weekMap.size} weeks`);
    sampleCount++;
  }
  console.log('');
  
  return adWeekMap;
}

/**
 * Write weekly data to advertData collection
 */
async function writeToAdvertData(adWeekMap) {
  console.log('💾 Writing data to advertData collection...');
  console.log('');
  
  const stats = {
    adsProcessed: 0,
    weeksWritten: 0,
    errors: 0
  };
  
  let batchCount = 0;
  let batch = db.batch();
  
  for (const [adId, weekMap] of adWeekMap) {
    try {
      stats.adsProcessed++;
      
      // Progress update every 10 ads
      if (stats.adsProcessed % 10 === 0) {
        console.log(`   📊 Progress: ${stats.adsProcessed}/${adWeekMap.size} ads processed (${stats.weeksWritten} weeks written)...`);
      }
      
      // Check if ad exists in advertData
      const adRef = db.collection('advertData').doc(adId);
      const adDoc = await adRef.get();
      
      if (!adDoc.exists) {
        if (stats.adsProcessed <= 5) {
          console.log(`   ⚠️  Ad ${adId} not found in advertData collection (skipping)`);
        }
        continue;
      }
      
      // Write each week's data
      for (const [weekId, weekData] of weekMap) {
        const weeklyRef = adRef
          .collection('ghlWeekly')
          .doc(weekId);
        
        const weeklyData = {
          leads: weekData.leads,
          bookedAppointments: weekData.bookedAppointments,
          deposits: weekData.deposits,
          cashCollected: weekData.cashCollected,
          cashAmount: weekData.cashAmount,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        };
        
        if (DRY_RUN) {
          console.log(`   [DRY RUN] Would write to advertData/${adId}/ghlWeekly/${weekId}:`, weeklyData);
        } else {
          batch.set(weeklyRef, weeklyData, { merge: true });
          batchCount++;
          stats.weeksWritten++;
          
          // Commit batch every 500 writes
          if (batchCount >= 500) {
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        }
      }
      
      // Update lastGHLSync timestamp on main ad document
      if (!DRY_RUN) {
        batch.update(adRef, {
          lastGHLSync: admin.firestore.FieldValue.serverTimestamp()
        });
        batchCount++;
        
        if (batchCount >= 500) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }
      
    } catch (error) {
      console.error(`   ❌ Error processing ad ${adId}:`, error.message);
      stats.errors++;
    }
  }
  
  // Commit remaining writes
  if (batchCount > 0 && !DRY_RUN) {
    await batch.commit();
  }
  
  console.log('');
  console.log('='.repeat(60));
  console.log('✅ WRITE COMPLETED!');
  console.log('='.repeat(60));
  console.log(`   📊 Ads processed: ${stats.adsProcessed}`);
  console.log(`   📅 Weeks written: ${stats.weeksWritten}`);
  console.log(`   ❌ Errors: ${stats.errors}`);
  console.log('='.repeat(60));
  console.log('');
  
  return stats;
}

/**
 * Main execution
 */
async function main() {
  console.log('');
  console.log('='.repeat(80));
  console.log('  GHL → ADVERTDATA SYNC');
  console.log('='.repeat(80));
  console.log('');
  
  if (DRY_RUN) {
    console.log('⚠️  DRY RUN MODE - No data will be written');
    console.log('');
  }
  
  console.log('This script will:');
  console.log('1. Fetch ALL opportunities from GHL API (last 2 months - Oct & Nov 2025)');
  console.log('2. Extract ALL 5 UTM parameters (h_ad_id, utm_source, utm_medium, utm_campaign, fbc_id)');
  console.log('3. Group opportunities by Facebook Ad ID and week');
  console.log('4. Write weekly metrics to advertData collection');
  console.log('');
  console.log('⚠️  Data source: GHL API ONLY (NOT Firebase collections)');
  console.log('📅 Date range: October 1, 2025 - November 9, 2025');
  console.log('');
  
  try {
    // Step 1: Fetch opportunities from GHL API
    const opportunities = await fetchAllOpportunitiesFromGHL();
    
    if (opportunities.length === 0) {
      console.log('⚠️  No opportunities found. Exiting.');
      process.exit(0);
    }
    
    // Step 2: Process and extract UTM data
    const { processedData, stats: extractionStats } = processOpportunities(opportunities);
    
    if (processedData.length === 0) {
      console.log('⚠️  No opportunities with h_ad_id found. Exiting.');
      process.exit(0);
    }
    
    // Step 3: Group by ad and week
    const adWeekMap = groupByAdAndWeek(processedData);
    
    // Step 4: Write to advertData
    const writeStats = await writeToAdvertData(adWeekMap);
    
    // Final summary
    console.log('');
    console.log('='.repeat(80));
    console.log('  SYNC COMPLETED SUCCESSFULLY!');
    console.log('='.repeat(80));
    console.log('');
    console.log('📊 Final Summary:');
    console.log(`   Total opportunities fetched: ${opportunities.length}`);
    console.log(`   Opportunities with h_ad_id: ${extractionStats.withHAdId}`);
    console.log(`   Opportunities with all 5 UTM params: ${extractionStats.withAllUTMParams}`);
    console.log(`   Ads updated: ${writeStats.adsProcessed}`);
    console.log(`   Weeks written: ${writeStats.weeksWritten}`);
    console.log(`   Errors: ${writeStats.errors}`);
    console.log('');
    console.log('Next Steps:');
    console.log('1. Verify data in Firebase Console');
    console.log('2. Check weekly breakdown for sample ads');
    console.log('3. Run verification script: node functions/verifyGHLAdvertDataSync.js');
    console.log('');
    console.log('='.repeat(80));
    console.log('');
    
    process.exit(0);
    
  } catch (error) {
    console.error('');
    console.error('='.repeat(80));
    console.error('❌ SYNC FAILED!');
    console.error('='.repeat(80));
    console.error('');
    console.error('Error:', error.message);
    console.error('');
    if (error.stack) {
      console.error('Stack trace:');
      console.error(error.stack);
    }
    console.error('');
    console.error('='.repeat(80));
    console.error('');
    
    process.exit(1);
  }
}

// Run the script
if (require.main === module) {
  main();
}

module.exports = {
  fetchAllOpportunitiesFromGHL,
  extractUTMParams,
  processOpportunities,
  groupByAdAndWeek,
  writeToAdvertData
};

