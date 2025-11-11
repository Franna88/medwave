/**
 * Test Single Ad Weekly Insights
 * Tests fetching and storing weekly data for a single ad
 */

const { fetchWeeklyInsights, storeWeeklyInsightsInFirestore, syncWeeklyInsightsForAd } = require('./lib/facebookAdsSync');
const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require(path.join(__dirname, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json'));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://medx-ai.firebaseio.com'
  });
}

const db = admin.firestore();

async function testSingleAd() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  SINGLE AD WEEKLY INSIGHTS TEST                       ');
  console.log('═══════════════════════════════════════════════════════\n');
  
  try {
    // Get first ad with spend > 0
    console.log('📋 Finding an ad with spend data...');
    const adsSnapshot = await db.collection('adPerformance')
      .where('facebookStats.spend', '>', 0)
      .limit(1)
      .get();
    
    if (adsSnapshot.empty) {
      console.log('❌ No ads found with spend data');
      return false;
    }
    
    const adDoc = adsSnapshot.docs[0];
    const adData = adDoc.data();
    const adId = adDoc.id;
    
    console.log(`✅ Found ad: ${adId}`);
    console.log(`   Name: ${adData.adName}`);
    console.log(`   Aggregated Spend: $${adData.facebookStats?.spend || 0}`);
    console.log(`   Date Range: ${adData.facebookStats?.dateStart} to ${adData.facebookStats?.dateStop}\n`);
    
    // Test 1: Fetch weekly data from Facebook API
    console.log('📊 Test 1: Fetching weekly data from Facebook API...');
    const endDate = new Date();
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - 1); // Last month
    
    const startDateStr = startDate.toISOString().split('T')[0];
    const endDateStr = endDate.toISOString().split('T')[0];
    
    const weeklyData = await fetchWeeklyInsights(adId, startDateStr, endDateStr);
    
    if (weeklyData.length > 0) {
      console.log(`✅ Fetched ${weeklyData.length} weeks of data`);
      weeklyData.forEach((week, index) => {
        console.log(`   Week ${week.weekNumber}: ${week.dateStart} to ${week.dateStop} - $${week.spend.toFixed(2)} spend`);
      });
    } else {
      console.log('⚠️  No weekly data returned (ad may not have been active in this period)');
    }
    
    // Test 2: Store in Firestore
    if (weeklyData.length > 0) {
      console.log('\n📝 Test 2: Storing weekly data in Firestore...');
      const storeResult = await storeWeeklyInsightsInFirestore(adId, weeklyData);
      
      if (storeResult.success) {
        console.log(`✅ Stored ${storeResult.stored} weeks in Firestore`);
      } else {
        console.log(`❌ Failed to store: ${storeResult.error}`);
      }
      
      // Test 3: Verify data in Firestore
      console.log('\n🔍 Test 3: Verifying data in Firestore...');
      const weeklySnapshot = await db
        .collection('adPerformance')
        .doc(adId)
        .collection('weeklyInsights')
        .orderBy('dateStart')
        .get();
      
      console.log(`✅ Found ${weeklySnapshot.size} weeks in Firestore`);
      
      if (weeklySnapshot.size > 0) {
        console.log('\n   Sample weeks:');
        weeklySnapshot.docs.slice(0, 3).forEach(doc => {
          const data = doc.data();
          const start = data.dateStart.toDate().toISOString().split('T')[0];
          const stop = data.dateStop.toDate().toISOString().split('T')[0];
          console.log(`   Week ${data.weekNumber}: ${start} to ${stop} - $${data.spend.toFixed(2)}`);
        });
      }
      
      // Test 4: Calculate totals
      console.log('\n📊 Test 4: Comparing totals...');
      let weeklyTotal = 0;
      weeklySnapshot.docs.forEach(doc => {
        weeklyTotal += doc.data().spend || 0;
      });
      
      const aggregated = adData.facebookStats?.spend || 0;
      const difference = Math.abs(aggregated - weeklyTotal);
      const percentDiff = aggregated > 0 ? (difference / aggregated) * 100 : 0;
      
      console.log(`   Aggregated spend: $${aggregated.toFixed(2)}`);
      console.log(`   Weekly total:     $${weeklyTotal.toFixed(2)}`);
      console.log(`   Difference:       $${difference.toFixed(2)} (${percentDiff.toFixed(1)}%)`);
      
      if (percentDiff < 20) {
        console.log('   ✅ Totals match within acceptable range');
      } else {
        console.log('   ⚠️  Large difference (may be due to different date ranges)');
      }
    }
    
    console.log('\n═══════════════════════════════════════════════════════');
    console.log('  TEST COMPLETE                                         ');
    console.log('═══════════════════════════════════════════════════════\n');
    
    return true;
  } catch (error) {
    console.error('\n❌ Test failed:', error);
    console.error(error.stack);
    return false;
  }
}

// Run test
if (require.main === module) {
  testSingleAd()
    .then((success) => {
      process.exit(success ? 0 : 1);
    })
    .catch((error) => {
      console.error('❌ Test crashed:', error);
      process.exit(1);
    });
}

module.exports = { testSingleAd };

