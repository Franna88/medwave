#!/usr/bin/env node
/**
 * Verification Script for GHL AdvertData Sync
 * 
 * Checks:
 * - How many opportunities from GHL API have h_ad_id
 * - How many ads in advertData have GHL data
 * - UTM parameter completeness
 * - Sample weekly breakdown
 * 
 * Usage: node functions/verifyGHLAdvertDataSync.js
 */

const admin = require('firebase-admin');
const { fetchAllOpportunitiesFromGHL, extractUTMParams } = require('./syncGHLToAdvertData');

// Initialize Firebase Admin
try {
  const serviceAccount = require('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  // Already initialized
}

const db = admin.firestore();

/**
 * Check advertData collection for GHL data
 */
async function checkAdvertDataGHLData() {
  console.log('📊 Checking advertData collection for GHL data...');
  console.log('');
  
  const advertsSnapshot = await db.collection('advertData').get();
  
  const stats = {
    totalAds: advertsSnapshot.size,
    adsWithGHLData: 0,
    adsWithoutGHLData: 0,
    totalWeeks: 0,
    sampleAds: []
  };
  
  for (const adDoc of advertsSnapshot.docs) {
    const adId = adDoc.id;
    const adData = adDoc.data();
    
    // Check if ad has GHL weekly data
    const ghlWeeklySnapshot = await db
      .collection('advertData')
      .doc(adId)
      .collection('ghlWeekly')
      .get();
    
    if (ghlWeeklySnapshot.size > 0) {
      stats.adsWithGHLData++;
      stats.totalWeeks += ghlWeeklySnapshot.size;
      
      // Collect sample ads (first 3)
      if (stats.sampleAds.length < 3) {
        const weeklyData = [];
        let totalLeads = 0;
        let totalBookings = 0;
        let totalDeposits = 0;
        let totalCash = 0;
        let totalCashAmount = 0;
        
        for (const weekDoc of ghlWeeklySnapshot.docs) {
          const weekData = weekDoc.data();
          weeklyData.push({
            weekId: weekDoc.id,
            leads: weekData.leads || 0,
            bookings: weekData.bookedAppointments || 0,
            deposits: weekData.deposits || 0,
            cash: weekData.cashCollected || 0,
            amount: weekData.cashAmount || 0
          });
          
          totalLeads += weekData.leads || 0;
          totalBookings += weekData.bookedAppointments || 0;
          totalDeposits += weekData.deposits || 0;
          totalCash += weekData.cashCollected || 0;
          totalCashAmount += weekData.cashAmount || 0;
        }
        
        stats.sampleAds.push({
          adId,
          adName: adData.adName || 'Unknown',
          campaignName: adData.campaignName || 'Unknown',
          weeksCount: ghlWeeklySnapshot.size,
          totalLeads,
          totalBookings,
          totalDeposits,
          totalCash,
          totalCashAmount,
          weeklyData: weeklyData.slice(0, 3) // First 3 weeks
        });
      }
    } else {
      stats.adsWithoutGHLData++;
    }
  }
  
  console.log('📊 AdvertData Collection Statistics:');
  console.log(`   Total ads: ${stats.totalAds}`);
  console.log(`   Ads with GHL data: ${stats.adsWithGHLData} (${((stats.adsWithGHLData/stats.totalAds)*100).toFixed(1)}%)`);
  console.log(`   Ads without GHL data: ${stats.adsWithoutGHLData} (${((stats.adsWithoutGHLData/stats.totalAds)*100).toFixed(1)}%)`);
  console.log(`   Total weeks with data: ${stats.totalWeeks}`);
  console.log(`   Average weeks per ad: ${stats.adsWithGHLData > 0 ? (stats.totalWeeks/stats.adsWithGHLData).toFixed(1) : 0}`);
  console.log('');
  
  return stats;
}

/**
 * Check GHL API opportunities for UTM completeness
 */
async function checkGHLAPIUTMQuality() {
  console.log('📊 Checking GHL API opportunities for UTM quality...');
  console.log('');
  
  const opportunities = await fetchAllOpportunitiesFromGHL();
  
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
    },
    sampleOpportunities: []
  };
  
  for (const opp of opportunities) {
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
    
    if (utmData.facebookAdId) {
      stats.withHAdId++;
      
      // Check if all 5 UTM params are present
      if (utmData.campaignName && utmData.adSetName && utmData.adName && utmData.adSetId) {
        stats.withAllUTMParams++;
      }
      
      // Collect sample (first 5)
      if (stats.sampleOpportunities.length < 5) {
        stats.sampleOpportunities.push({
          name: opp.name,
          h_ad_id: utmData.facebookAdId,
          utm_source: utmData.campaignName,
          utm_medium: utmData.adSetName,
          utm_campaign: utmData.adName,
          fbc_id: utmData.adSetId,
          complete: !!(utmData.campaignName && utmData.adSetName && utmData.adName && utmData.adSetId)
        });
      }
    } else {
      stats.withoutHAdId++;
    }
  }
  
  console.log('📊 GHL API UTM Quality Statistics:');
  console.log(`   Total opportunities: ${stats.total}`);
  console.log(`   With h_ad_id: ${stats.withHAdId} (${((stats.withHAdId/stats.total)*100).toFixed(1)}%)`);
  console.log(`   With ALL 5 UTM params: ${stats.withAllUTMParams} (${((stats.withAllUTMParams/stats.total)*100).toFixed(1)}%)`);
  console.log(`   Without h_ad_id: ${stats.withoutHAdId} (${((stats.withoutHAdId/stats.total)*100).toFixed(1)}%)`);
  console.log('');
  console.log('📊 Individual UTM Parameter Completeness:');
  console.log(`   h_ad_id: ${stats.utmQuality.hasHAdId} (${((stats.utmQuality.hasHAdId/stats.total)*100).toFixed(1)}%)`);
  console.log(`   utm_source (campaign): ${stats.utmQuality.hasCampaignName} (${((stats.utmQuality.hasCampaignName/stats.total)*100).toFixed(1)}%)`);
  console.log(`   utm_medium (ad set): ${stats.utmQuality.hasAdSetName} (${((stats.utmQuality.hasAdSetName/stats.total)*100).toFixed(1)}%)`);
  console.log(`   utm_campaign (ad): ${stats.utmQuality.hasAdName} (${((stats.utmQuality.hasAdName/stats.total)*100).toFixed(1)}%)`);
  console.log(`   fbc_id (ad set ID): ${stats.utmQuality.hasAdSetId} (${((stats.utmQuality.hasAdSetId/stats.total)*100).toFixed(1)}%)`);
  console.log('');
  
  return stats;
}

/**
 * Main execution
 */
async function main() {
  console.log('');
  console.log('='.repeat(80));
  console.log('  GHL ADVERTDATA SYNC VERIFICATION');
  console.log('='.repeat(80));
  console.log('');
  
  try {
    // Check 1: GHL API UTM Quality
    const ghlStats = await checkGHLAPIUTMQuality();
    
    // Check 2: AdvertData GHL Data
    const advertDataStats = await checkAdvertDataGHLData();
    
    // Show sample opportunities
    if (ghlStats.sampleOpportunities.length > 0) {
      console.log('📋 Sample Opportunities from GHL API:');
      ghlStats.sampleOpportunities.forEach((sample, idx) => {
        console.log(`   ${idx + 1}. ${sample.name}`);
        console.log(`      h_ad_id: ${sample.h_ad_id || '❌ MISSING'}`);
        console.log(`      utm_source: ${sample.utm_source || '❌ MISSING'}`);
        console.log(`      utm_medium: ${sample.utm_medium || '❌ MISSING'}`);
        console.log(`      utm_campaign: ${sample.utm_campaign || '❌ MISSING'}`);
        console.log(`      fbc_id: ${sample.fbc_id || '❌ MISSING'}`);
        console.log(`      Complete: ${sample.complete ? '✅' : '❌'}`);
        console.log('');
      });
    }
    
    // Show sample ads with weekly data
    if (advertDataStats.sampleAds.length > 0) {
      console.log('📋 Sample Ads with Weekly GHL Data:');
      advertDataStats.sampleAds.forEach((sample, idx) => {
        console.log(`   ${idx + 1}. ${sample.adName}`);
        console.log(`      Campaign: ${sample.campaignName}`);
        console.log(`      Ad ID: ${sample.adId}`);
        console.log(`      Weeks: ${sample.weeksCount}`);
        console.log(`      Total Leads: ${sample.totalLeads}`);
        console.log(`      Total Bookings: ${sample.totalBookings}`);
        console.log(`      Total Deposits: ${sample.totalDeposits}`);
        console.log(`      Total Cash: ${sample.totalCash}`);
        console.log(`      Total Amount: R${sample.totalCashAmount.toFixed(2)}`);
        console.log('');
        console.log('      Sample Weekly Breakdown (first 3 weeks):');
        sample.weeklyData.forEach(week => {
          console.log(`         ${week.weekId}: ${week.leads} leads, ${week.bookings} bookings, ${week.deposits} deposits, ${week.cash} cash (R${week.amount.toFixed(2)})`);
        });
        console.log('');
      });
    }
    
    // Calculate match rate
    const matchRate = ghlStats.withHAdId > 0 
      ? ((advertDataStats.adsWithGHLData / ghlStats.withHAdId) * 100).toFixed(1)
      : 0;
    
    // Final summary
    console.log('');
    console.log('='.repeat(80));
    console.log('  VERIFICATION SUMMARY');
    console.log('='.repeat(80));
    console.log('');
    console.log('✅ Data Quality:');
    console.log(`   GHL opportunities with h_ad_id: ${ghlStats.withHAdId}`);
    console.log(`   GHL opportunities with all 5 UTM params: ${ghlStats.withAllUTMParams}`);
    console.log(`   Ads in advertData with GHL data: ${advertDataStats.adsWithGHLData}`);
    console.log(`   Match rate: ${matchRate}%`);
    console.log('');
    
    if (ghlStats.withHAdId === 0) {
      console.log('⚠️  WARNING: No opportunities found with h_ad_id!');
      console.log('   Check that UTM parameters are properly configured in GHL.');
      console.log('');
    } else if (advertDataStats.adsWithGHLData === 0) {
      console.log('⚠️  WARNING: No ads in advertData have GHL data!');
      console.log('   Run the sync script: node functions/syncGHLToAdvertData.js');
      console.log('');
    } else if (matchRate < 50) {
      console.log('⚠️  WARNING: Low match rate!');
      console.log('   Some opportunities may not match ads in advertData.');
      console.log('   Check that Facebook ads are properly synced.');
      console.log('');
    } else {
      console.log('✅ Verification passed! Data looks good.');
      console.log('');
    }
    
    console.log('='.repeat(80));
    console.log('');
    
    process.exit(0);
    
  } catch (error) {
    console.error('');
    console.error('='.repeat(80));
    console.error('❌ VERIFICATION FAILED!');
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
  checkAdvertDataGHLData,
  checkGHLAPIUTMQuality
};

