#!/usr/bin/env node
/**
 * Population Script for advertData Collection
 * One-time script to populate advertData with Facebook ads from last 6 months
 * 
 * Usage: node functions/populateAdvertData.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json');
const { fetchAndStoreAdvertsFromFacebook, syncAllAdvertsWithGHL } = require('./lib/advertDataSync');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function main() {
  console.log('');
  console.log('=' .repeat(80));
  console.log('  ADVERTDATA COLLECTION POPULATION');
  console.log('=' .repeat(80));
  console.log('');
  console.log('This script will:');
  console.log('1. Fetch all Facebook ads from the last 6 months');
  console.log('2. Store each ad in the advertData collection');
  console.log('3. Fetch and store weekly insights for each ad');
  console.log('4. Initialize GHL weekly structure (empty documents)');
  console.log('');
  console.log('⚠️  This may take several minutes depending on the number of ads.');
  console.log('');
  
  try {
    // Step 1 & 2 & 3: Fetch and store Facebook ads with weekly insights
    console.log('🚀 Step 1-3: Fetching and storing Facebook ads with weekly insights...');
    console.log('');
    
    const facebookResult = await fetchAndStoreAdvertsFromFacebook(6); // 6 months
    
    if (!facebookResult.success) {
      throw new Error('Facebook sync failed');
    }
    
    console.log('');
    console.log('✅ Facebook data sync completed successfully!');
    console.log('   Stats:', facebookResult.stats);
    console.log('');
    
    // Step 4: Initialize GHL weekly structure
    console.log('🔄 Step 4: Initializing GHL weekly structure...');
    console.log('');
    
    const ghlResult = await syncAllAdvertsWithGHL();
    
    if (!ghlResult.success) {
      throw new Error('GHL structure initialization failed');
    }
    
    console.log('');
    console.log('✅ GHL structure initialized successfully!');
    console.log(`   Initialized: ${ghlResult.initialized} adverts`);
    console.log('');
    
    // Summary
    console.log('');
    console.log('=' .repeat(80));
    console.log('  POPULATION COMPLETED SUCCESSFULLY!');
    console.log('=' .repeat(80));
    console.log('');
    console.log('📊 Summary:');
    console.log(`   - Total Facebook Ads: ${facebookResult.stats.totalAds}`);
    console.log(`   - Ads Stored: ${facebookResult.stats.stored}`);
    console.log(`   - Insights Synced: ${facebookResult.stats.insightsSynced}`);
    console.log(`   - GHL Structure Initialized: ${ghlResult.initialized}`);
    console.log(`   - Errors: ${facebookResult.stats.errors}`);
    console.log('');
    console.log('Next Steps:');
    console.log('1. Run backfillGHLWeekly.js to populate historical GHL data');
    console.log('2. Verify data in Firebase Console');
    console.log('3. Test scheduled sync functions');
    console.log('');
    console.log('=' .repeat(80));
    console.log('');
    
    process.exit(0);
    
  } catch (error) {
    console.error('');
    console.error('=' .repeat(80));
    console.error('❌ POPULATION FAILED!');
    console.error('=' .repeat(80));
    console.error('');
    console.error('Error:', error.message);
    console.error('');
    if (error.stack) {
      console.error('Stack trace:');
      console.error(error.stack);
    }
    console.error('');
    console.error('=' .repeat(80));
    console.error('');
    
    process.exit(1);
  }
}

// Run the script
main();

