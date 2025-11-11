#!/usr/bin/env node
/**
 * Check existing adPerformance data and copy to advertData
 * This avoids hitting Facebook API limits
 */

const admin = require('firebase-admin');
const serviceAccount = require('../medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json');

// Initialize Firebase Admin
try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  // Already initialized
}

const db = admin.firestore();

async function main() {
  console.log('');
  console.log('='.repeat(80));
  console.log('  CHECKING EXISTING DATA');
  console.log('='.repeat(80));
  console.log('');
  
  try {
    // Check adPerformance collection
    console.log('📊 Checking adPerformance collection...');
    const adPerfSnapshot = await db.collection('adPerformance').get();
    console.log(`   Found ${adPerfSnapshot.size} ads in adPerformance`);
    
    // Check advertData collection
    console.log('📊 Checking advertData collection...');
    const advertDataSnapshot = await db.collection('advertData').get();
    console.log(`   Found ${advertDataSnapshot.size} ads in advertData`);
    
    // Check opportunityStageHistory
    console.log('📊 Checking opportunityStageHistory...');
    const oppHistorySnapshot = await db.collection('opportunityStageHistory')
      .where('facebookAdId', '!=', '')
      .limit(100)
      .get();
    console.log(`   Found ${oppHistorySnapshot.size} opportunities with facebookAdId (sample)`);
    
    if (oppHistorySnapshot.size > 0) {
      const sampleOpp = oppHistorySnapshot.docs[0].data();
      console.log('   Sample opportunity:');
      console.log(`      - facebookAdId: ${sampleOpp.facebookAdId}`);
      console.log(`      - adName: ${sampleOpp.adName}`);
      console.log(`      - campaignName: ${sampleOpp.campaignName}`);
    }
    
    console.log('');
    console.log('='.repeat(80));
    console.log('');
    
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();

