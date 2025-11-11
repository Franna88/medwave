#!/usr/bin/env node
/**
 * Test Script for GHL AdvertData Sync
 * 
 * Tests with a small sample of opportunities to verify:
 * - All 5 UTM parameters are extracted correctly
 * - Data is grouped properly by ad and week
 * - No errors in processing logic
 * 
 * Usage: node functions/testGHLSync.js
 */

const admin = require('firebase-admin');
const { 
  fetchAllOpportunitiesFromGHL, 
  extractUTMParams, 
  processOpportunities,
  groupByAdAndWeek
} = require('./syncGHLToAdvertData');

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
 * Test UTM extraction with sample opportunities
 */
async function testUTMExtraction() {
  console.log('');
  console.log('='.repeat(80));
  console.log('  TEST 1: UTM PARAMETER EXTRACTION');
  console.log('='.repeat(80));
  console.log('');
  
  try {
    console.log('📋 Fetching sample opportunities from GHL API...');
    const opportunities = await fetchAllOpportunitiesFromGHL();
    
    if (opportunities.length === 0) {
      console.log('⚠️  No opportunities found');
      return false;
    }
    
    console.log(`✅ Fetched ${opportunities.length} opportunities`);
    console.log('');
    
    // Test extraction on first 10 opportunities
    const sampleSize = Math.min(10, opportunities.length);
    console.log(`🔍 Testing UTM extraction on first ${sampleSize} opportunities...`);
    console.log('');
    
    let passCount = 0;
    let failCount = 0;
    
    for (let i = 0; i < sampleSize; i++) {
      const opp = opportunities[i];
      const utmData = extractUTMParams(opp);
      
      console.log(`${i + 1}. ${opp.name || 'Unnamed'}`);
      
      if (!utmData) {
        console.log('   ❌ No attribution data found');
        failCount++;
        console.log('');
        continue;
      }
      
      console.log(`   h_ad_id: ${utmData.facebookAdId || '❌ MISSING'}`);
      console.log(`   utm_source: ${utmData.campaignName || '❌ MISSING'}`);
      console.log(`   utm_medium: ${utmData.adSetName || '❌ MISSING'}`);
      console.log(`   utm_campaign: ${utmData.adName || '❌ MISSING'}`);
      console.log(`   fbc_id: ${utmData.adSetId || '❌ MISSING'}`);
      
      // Check if all 5 params are present
      const hasAll = utmData.facebookAdId && utmData.campaignName && 
                     utmData.adSetName && utmData.adName && utmData.adSetId;
      
      if (hasAll) {
        console.log('   ✅ All 5 UTM parameters present');
        passCount++;
      } else if (utmData.facebookAdId) {
        console.log('   ⚠️  Has h_ad_id but missing some UTM params');
        passCount++;
      } else {
        console.log('   ❌ Missing h_ad_id (will be skipped)');
        failCount++;
      }
      
      console.log('');
    }
    
    console.log('📊 Test Results:');
    console.log(`   Pass: ${passCount}/${sampleSize}`);
    console.log(`   Fail: ${failCount}/${sampleSize}`);
    console.log('');
    
    return passCount > 0;
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    return false;
  }
}

/**
 * Test ad matching with advertData collection
 */
async function testAdMatching() {
  console.log('');
  console.log('='.repeat(80));
  console.log('  TEST 2: AD MATCHING');
  console.log('='.repeat(80));
  console.log('');
  
  try {
    console.log('📋 Fetching opportunities from GHL API...');
    const opportunities = await fetchAllOpportunitiesFromGHL();
    
    console.log('🔍 Processing opportunities...');
    const { processedData } = processOpportunities(opportunities);
    
    if (processedData.length === 0) {
      console.log('⚠️  No opportunities with h_ad_id found');
      return false;
    }
    
    console.log(`✅ Found ${processedData.length} opportunities with h_ad_id`);
    console.log('');
    
    // Get unique ad IDs
    const uniqueAdIds = new Set(processedData.map(opp => opp.facebookAdId));
    console.log(`📊 Unique Facebook Ad IDs: ${uniqueAdIds.size}`);
    console.log('');
    
    // Check if these ads exist in advertData
    console.log('🔍 Checking if ads exist in advertData collection...');
    
    let matchedCount = 0;
    let notFoundCount = 0;
    const sampleMatches = [];
    
    for (const adId of Array.from(uniqueAdIds).slice(0, 10)) {
      const adDoc = await db.collection('advertData').doc(adId).get();
      
      if (adDoc.exists) {
        matchedCount++;
        if (sampleMatches.length < 3) {
          const adData = adDoc.data();
          sampleMatches.push({
            adId,
            adName: adData.adName || 'Unknown',
            campaignName: adData.campaignName || 'Unknown'
          });
        }
      } else {
        notFoundCount++;
        if (notFoundCount <= 3) {
          console.log(`   ⚠️  Ad ${adId} not found in advertData`);
        }
      }
    }
    
    console.log('');
    console.log('📊 Matching Results (sample of 10):');
    console.log(`   Found in advertData: ${matchedCount}`);
    console.log(`   Not found: ${notFoundCount}`);
    console.log('');
    
    if (sampleMatches.length > 0) {
      console.log('✅ Sample Matched Ads:');
      sampleMatches.forEach((ad, idx) => {
        console.log(`   ${idx + 1}. ${ad.adName}`);
        console.log(`      Campaign: ${ad.campaignName}`);
        console.log(`      Ad ID: ${ad.adId}`);
        console.log('');
      });
    }
    
    return matchedCount > 0;
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    return false;
  }
}

/**
 * Test weekly grouping logic
 */
async function testWeeklyGrouping() {
  console.log('');
  console.log('='.repeat(80));
  console.log('  TEST 3: WEEKLY GROUPING');
  console.log('='.repeat(80));
  console.log('');
  
  try {
    console.log('📋 Fetching opportunities from GHL API...');
    const opportunities = await fetchAllOpportunitiesFromGHL();
    
    console.log('🔍 Processing opportunities...');
    const { processedData } = processOpportunities(opportunities);
    
    if (processedData.length === 0) {
      console.log('⚠️  No opportunities with h_ad_id found');
      return false;
    }
    
    console.log('📅 Grouping by ad and week...');
    const adWeekMap = groupByAdAndWeek(processedData);
    
    console.log(`✅ Grouped data for ${adWeekMap.size} ads`);
    console.log('');
    
    // Show sample grouping for first 3 ads
    let sampleCount = 0;
    for (const [adId, weekMap] of adWeekMap) {
      if (sampleCount >= 3) break;
      
      console.log(`📊 Ad: ${adId}`);
      console.log(`   Weeks: ${weekMap.size}`);
      
      // Show first 2 weeks
      let weekCount = 0;
      for (const [weekId, weekData] of weekMap) {
        if (weekCount >= 2) break;
        
        console.log(`   Week ${weekId}:`);
        console.log(`      Leads: ${weekData.leads}`);
        console.log(`      Bookings: ${weekData.bookedAppointments}`);
        console.log(`      Deposits: ${weekData.deposits}`);
        console.log(`      Cash: ${weekData.cashCollected}`);
        console.log(`      Amount: R${weekData.cashAmount.toFixed(2)}`);
        
        weekCount++;
      }
      
      console.log('');
      sampleCount++;
    }
    
    return true;
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
    return false;
  }
}

/**
 * Main test execution
 */
async function main() {
  console.log('');
  console.log('='.repeat(80));
  console.log('  GHL ADVERTDATA SYNC - TEST SUITE');
  console.log('='.repeat(80));
  console.log('');
  console.log('This will test:');
  console.log('1. UTM parameter extraction (all 5 params)');
  console.log('2. Ad matching with advertData collection');
  console.log('3. Weekly grouping logic');
  console.log('');
  console.log('⚠️  This is a READ-ONLY test - no data will be written');
  console.log('');
  
  const results = {
    utmExtraction: false,
    adMatching: false,
    weeklyGrouping: false
  };
  
  try {
    // Test 1: UTM Extraction
    results.utmExtraction = await testUTMExtraction();
    
    // Test 2: Ad Matching
    results.adMatching = await testAdMatching();
    
    // Test 3: Weekly Grouping
    results.weeklyGrouping = await testWeeklyGrouping();
    
    // Final summary
    console.log('');
    console.log('='.repeat(80));
    console.log('  TEST SUMMARY');
    console.log('='.repeat(80));
    console.log('');
    console.log(`1. UTM Extraction: ${results.utmExtraction ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`2. Ad Matching: ${results.adMatching ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`3. Weekly Grouping: ${results.weeklyGrouping ? '✅ PASS' : '❌ FAIL'}`);
    console.log('');
    
    const allPassed = results.utmExtraction && results.adMatching && results.weeklyGrouping;
    
    if (allPassed) {
      console.log('✅ ALL TESTS PASSED!');
      console.log('');
      console.log('Next Steps:');
      console.log('1. Run dry-run sync: node functions/syncGHLToAdvertData.js --dry-run');
      console.log('2. Run full sync: node functions/syncGHLToAdvertData.js');
      console.log('3. Verify results: node functions/verifyGHLAdvertDataSync.js');
    } else {
      console.log('❌ SOME TESTS FAILED');
      console.log('');
      console.log('Please review the errors above before running the full sync.');
    }
    
    console.log('');
    console.log('='.repeat(80));
    console.log('');
    
    process.exit(allPassed ? 0 : 1);
    
  } catch (error) {
    console.error('');
    console.error('='.repeat(80));
    console.error('❌ TEST SUITE FAILED!');
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

// Run the test suite
if (require.main === module) {
  main();
}

module.exports = {
  testUTMExtraction,
  testAdMatching,
  testWeeklyGrouping
};

