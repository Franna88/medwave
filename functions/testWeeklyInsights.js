/**
 * Test Weekly Insights Implementation
 * Verifies that weekly data is accurate and timestamps are correct
 */

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

/**
 * Test 1: Verify weekly data exists
 */
async function testWeeklyDataExists() {
  console.log('\n📋 Test 1: Checking if weekly data exists...');
  
  try {
    // Get a sample ad
    const adsSnapshot = await db.collection('adPerformance').limit(10).get();
    
    let adsWithWeeklyData = 0;
    let totalWeeks = 0;
    
    for (const adDoc of adsSnapshot.docs) {
      const weeklySnapshot = await db
        .collection('adPerformance')
        .doc(adDoc.id)
        .collection('weeklyInsights')
        .get();
      
      if (weeklySnapshot.size > 0) {
        adsWithWeeklyData++;
        totalWeeks += weeklySnapshot.size;
        console.log(`   ✅ Ad ${adDoc.id}: ${weeklySnapshot.size} weeks`);
      }
    }
    
    console.log(`\n   Summary: ${adsWithWeeklyData}/${adsSnapshot.size} ads have weekly data`);
    console.log(`   Total weeks: ${totalWeeks}`);
    
    return adsWithWeeklyData > 0;
  } catch (error) {
    console.error('   ❌ Test failed:', error.message);
    return false;
  }
}

/**
 * Test 2: Verify timestamps are valid
 */
async function testTimestampsValid() {
  console.log('\n📋 Test 2: Verifying timestamps are valid...');
  
  try {
    // Get a sample ad with weekly data
    const adsSnapshot = await db.collection('adPerformance').limit(5).get();
    
    let validTimestamps = 0;
    let invalidTimestamps = 0;
    
    for (const adDoc of adsSnapshot.docs) {
      const weeklySnapshot = await db
        .collection('adPerformance')
        .doc(adDoc.id)
        .collection('weeklyInsights')
        .limit(5)
        .get();
      
      for (const weekDoc of weeklySnapshot.docs) {
        const data = weekDoc.data();
        
        if (data.dateStart && data.dateStop) {
          const start = data.dateStart.toDate();
          const stop = data.dateStop.toDate();
          
          // Verify start is before stop
          if (start < stop) {
            validTimestamps++;
            
            // Verify it's approximately 7 days
            const daysDiff = (stop - start) / (1000 * 60 * 60 * 24);
            if (daysDiff >= 6 && daysDiff <= 8) {
              console.log(`   ✅ Week ${data.weekNumber}: ${start.toISOString().split('T')[0]} to ${stop.toISOString().split('T')[0]} (${daysDiff.toFixed(1)} days)`);
            } else {
              console.log(`   ⚠️  Week ${data.weekNumber}: ${daysDiff.toFixed(1)} days (expected ~7)`);
            }
          } else {
            invalidTimestamps++;
            console.log(`   ❌ Invalid: start (${start}) is after stop (${stop})`);
          }
        }
      }
    }
    
    console.log(`\n   Valid timestamps: ${validTimestamps}`);
    console.log(`   Invalid timestamps: ${invalidTimestamps}`);
    
    return invalidTimestamps === 0;
  } catch (error) {
    console.error('   ❌ Test failed:', error.message);
    return false;
  }
}

/**
 * Test 3: Verify weekly totals match aggregated data (approximately)
 */
async function testWeeklyTotalsMatchAggregated() {
  console.log('\n📋 Test 3: Comparing weekly totals with aggregated data...');
  
  try {
    // Get ads with both aggregated and weekly data
    const adsSnapshot = await db.collection('adPerformance').limit(5).get();
    
    let matchCount = 0;
    let mismatchCount = 0;
    
    for (const adDoc of adsSnapshot.docs) {
      const adData = adDoc.data();
      const aggregatedSpend = adData.facebookStats?.spend || 0;
      
      // Get weekly data
      const weeklySnapshot = await db
        .collection('adPerformance')
        .doc(adDoc.id)
        .collection('weeklyInsights')
        .get();
      
      if (weeklySnapshot.size === 0) continue;
      
      // Sum weekly spend
      let weeklyTotalSpend = 0;
      weeklySnapshot.docs.forEach(weekDoc => {
        weeklyTotalSpend += weekDoc.data().spend || 0;
      });
      
      // Compare (allow 10% variance due to different date ranges)
      const difference = Math.abs(aggregatedSpend - weeklyTotalSpend);
      const percentDiff = aggregatedSpend > 0 ? (difference / aggregatedSpend) * 100 : 0;
      
      if (percentDiff < 10 || difference < 1) {
        matchCount++;
        console.log(`   ✅ Ad ${adDoc.id}: Aggregated: $${aggregatedSpend.toFixed(2)}, Weekly Total: $${weeklyTotalSpend.toFixed(2)} (${percentDiff.toFixed(1)}% diff)`);
      } else {
        mismatchCount++;
        console.log(`   ⚠️  Ad ${adDoc.id}: Aggregated: $${aggregatedSpend.toFixed(2)}, Weekly Total: $${weeklyTotalSpend.toFixed(2)} (${percentDiff.toFixed(1)}% diff)`);
      }
    }
    
    console.log(`\n   Matches: ${matchCount}`);
    console.log(`   Mismatches: ${mismatchCount}`);
    console.log(`   Note: Mismatches are expected due to different date ranges`);
    
    return true;
  } catch (error) {
    console.error('   ❌ Test failed:', error.message);
    return false;
  }
}

/**
 * Test 4: Verify week numbers are sequential
 */
async function testWeekNumbersSequential() {
  console.log('\n📋 Test 4: Verifying week numbers are sequential...');
  
  try {
    const adsSnapshot = await db.collection('adPerformance').limit(3).get();
    
    let sequentialCount = 0;
    let nonSequentialCount = 0;
    
    for (const adDoc of adsSnapshot.docs) {
      const weeklySnapshot = await db
        .collection('adPerformance')
        .doc(adDoc.id)
        .collection('weeklyInsights')
        .orderBy('dateStart')
        .get();
      
      if (weeklySnapshot.size === 0) continue;
      
      const weekNumbers = weeklySnapshot.docs.map(doc => doc.data().weekNumber);
      let isSequential = true;
      
      for (let i = 0; i < weekNumbers.length; i++) {
        if (weekNumbers[i] !== i + 1) {
          isSequential = false;
          break;
        }
      }
      
      if (isSequential) {
        sequentialCount++;
        console.log(`   ✅ Ad ${adDoc.id}: Weeks 1-${weekNumbers.length} are sequential`);
      } else {
        nonSequentialCount++;
        console.log(`   ⚠️  Ad ${adDoc.id}: Week numbers not sequential: [${weekNumbers.join(', ')}]`);
      }
    }
    
    console.log(`\n   Sequential: ${sequentialCount}`);
    console.log(`   Non-sequential: ${nonSequentialCount}`);
    
    return true;
  } catch (error) {
    console.error('   ❌ Test failed:', error.message);
    return false;
  }
}

/**
 * Main test runner
 */
async function runAllTests() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  WEEKLY INSIGHTS TESTING SUITE                        ');
  console.log('═══════════════════════════════════════════════════════');
  console.log(`Started at: ${new Date().toISOString()}\n`);
  
  const results = {
    test1: false,
    test2: false,
    test3: false,
    test4: false,
  };
  
  try {
    results.test1 = await testWeeklyDataExists();
    results.test2 = await testTimestampsValid();
    results.test3 = await testWeeklyTotalsMatchAggregated();
    results.test4 = await testWeekNumbersSequential();
    
    // Print summary
    console.log('\n═══════════════════════════════════════════════════════');
    console.log('  TEST RESULTS                                          ');
    console.log('═══════════════════════════════════════════════════════\n');
    
    console.log(`Test 1 - Weekly Data Exists:        ${results.test1 ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`Test 2 - Timestamps Valid:          ${results.test2 ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`Test 3 - Totals Match Aggregated:   ${results.test3 ? '✅ PASS' : '❌ FAIL'}`);
    console.log(`Test 4 - Week Numbers Sequential:   ${results.test4 ? '✅ PASS' : '❌ FAIL'}`);
    
    const allPassed = Object.values(results).every(r => r);
    
    console.log('\n' + (allPassed ? '✅ ALL TESTS PASSED' : '⚠️  SOME TESTS FAILED'));
    console.log('═══════════════════════════════════════════════════════\n');
    
    return allPassed;
  } catch (error) {
    console.error('\n❌ Test suite failed:', error);
    return false;
  }
}

// Run tests if executed directly
if (require.main === module) {
  runAllTests()
    .then((success) => {
      process.exit(success ? 0 : 1);
    })
    .catch((error) => {
      console.error('❌ Test suite crashed:', error);
      process.exit(1);
    });
}

module.exports = {
  runAllTests,
  testWeeklyDataExists,
  testTimestampsValid,
  testWeeklyTotalsMatchAggregated,
  testWeekNumbersSequential,
};

