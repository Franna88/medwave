/**
 * Backfill Weekly Insights Script
 * Fetches 6 months of historical weekly ad performance data from Facebook API
 * and stores it in Firestore for timeline analysis
 */

const admin = require('firebase-admin');
const { syncWeeklyInsightsForAd } = require('./lib/facebookAdsSync');
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
 * Get all ad IDs from adPerformance collection
 */
async function getAllAdIds() {
  try {
    console.log('📋 Fetching all ad IDs from Firestore...');
    
    const snapshot = await db.collection('adPerformance').get();
    const adIds = snapshot.docs.map(doc => doc.id);
    
    console.log(`✅ Found ${adIds.length} ads in Firestore`);
    return adIds;
  } catch (error) {
    console.error('❌ Error fetching ad IDs:', error.message);
    throw error;
  }
}

/**
 * Process ads in batches to respect rate limits
 */
async function processAdsBatch(adIds, batchSize = 10, delayMs = 3000) {
  const stats = {
    total: adIds.length,
    processed: 0,
    successful: 0,
    failed: 0,
    totalWeeksStored: 0,
    errors: []
  };

  console.log(`\n🚀 Starting backfill for ${adIds.length} ads`);
  console.log(`   Batch size: ${batchSize} ads`);
  console.log(`   Delay between batches: ${delayMs}ms`);
  console.log(`   Fetching: 6 months of weekly data per ad\n`);

  // Process ads in batches
  for (let i = 0; i < adIds.length; i += batchSize) {
    const batch = adIds.slice(i, i + batchSize);
    const batchNumber = Math.floor(i / batchSize) + 1;
    const totalBatches = Math.ceil(adIds.length / batchSize);

    console.log(`\n📦 Processing batch ${batchNumber}/${totalBatches} (${batch.length} ads)...`);

    // Process all ads in current batch concurrently
    const batchPromises = batch.map(async (adId) => {
      try {
        console.log(`   🔄 Processing ad: ${adId}`);
        
        const result = await syncWeeklyInsightsForAd(adId, 6); // 6 months
        
        stats.processed++;
        
        if (result.success) {
          stats.successful++;
          stats.totalWeeksStored += result.weeksStored || 0;
          console.log(`   ✅ Ad ${adId}: ${result.weeksStored} weeks stored`);
        } else {
          stats.failed++;
          stats.errors.push({
            adId: adId,
            error: result.error || 'Unknown error'
          });
          console.log(`   ❌ Ad ${adId}: Failed - ${result.error}`);
        }
      } catch (error) {
        stats.processed++;
        stats.failed++;
        stats.errors.push({
          adId: adId,
          error: error.message
        });
        console.error(`   ❌ Ad ${adId}: Exception - ${error.message}`);
      }
    });

    // Wait for all ads in batch to complete
    await Promise.all(batchPromises);

    console.log(`   ✅ Batch ${batchNumber} completed`);
    console.log(`   Progress: ${stats.processed}/${stats.total} ads processed`);

    // Delay between batches (except for last batch)
    if (i + batchSize < adIds.length) {
      console.log(`   ⏳ Waiting ${delayMs}ms before next batch...`);
      await new Promise(resolve => setTimeout(resolve, delayMs));
    }
  }

  return stats;
}

/**
 * Main backfill function
 */
async function backfillWeeklyInsights() {
  const startTime = Date.now();
  
  console.log('═══════════════════════════════════════════════════════');
  console.log('  WEEKLY INSIGHTS BACKFILL - 6 MONTHS HISTORICAL DATA  ');
  console.log('═══════════════════════════════════════════════════════');
  console.log(`Started at: ${new Date().toISOString()}\n`);

  try {
    // Get all ad IDs
    const adIds = await getAllAdIds();

    if (adIds.length === 0) {
      console.log('⚠️  No ads found in Firestore. Run Facebook sync first.');
      return;
    }

    // Process ads in batches
    const stats = await processAdsBatch(adIds, 10, 3000);

    // Calculate duration
    const duration = ((Date.now() - startTime) / 1000 / 60).toFixed(2);

    // Print final summary
    console.log('\n═══════════════════════════════════════════════════════');
    console.log('  BACKFILL COMPLETE                                     ');
    console.log('═══════════════════════════════════════════════════════');
    console.log(`\n📊 Final Statistics:`);
    console.log(`   Total Ads: ${stats.total}`);
    console.log(`   Processed: ${stats.processed}`);
    console.log(`   Successful: ${stats.successful}`);
    console.log(`   Failed: ${stats.failed}`);
    console.log(`   Total Weeks Stored: ${stats.totalWeeksStored}`);
    console.log(`   Duration: ${duration} minutes`);

    if (stats.errors.length > 0) {
      console.log(`\n⚠️  Errors (${stats.errors.length}):`);
      stats.errors.slice(0, 10).forEach(err => {
        console.log(`   - Ad ${err.adId}: ${err.error}`);
      });
      if (stats.errors.length > 10) {
        console.log(`   ... and ${stats.errors.length - 10} more errors`);
      }
    }

    console.log(`\n✅ Backfill completed at: ${new Date().toISOString()}`);
    console.log('═══════════════════════════════════════════════════════\n');

    // Save error log if there are errors
    if (stats.errors.length > 0) {
      const errorLog = {
        timestamp: new Date().toISOString(),
        totalErrors: stats.errors.length,
        errors: stats.errors
      };
      
      const fs = require('fs');
      const errorLogPath = `./backfill_errors_${Date.now()}.json`;
      fs.writeFileSync(errorLogPath, JSON.stringify(errorLog, null, 2));
      console.log(`📝 Error log saved to: ${errorLogPath}\n`);
    }

  } catch (error) {
    console.error('\n❌ Backfill failed with error:', error);
    throw error;
  }
}

// Run backfill if executed directly
if (require.main === module) {
  backfillWeeklyInsights()
    .then(() => {
      console.log('✅ Script completed successfully');
      process.exit(0);
    })
    .catch((error) => {
      console.error('❌ Script failed:', error);
      process.exit(1);
    });
}

module.exports = {
  backfillWeeklyInsights,
  getAllAdIds,
  processAdsBatch
};

