/**
 * ONE-TIME MIGRATION SCRIPT
 * Migrate data from adPerformanceCosts to new adPerformance collection
 * Run this once to populate initial data
 * 
 * Usage: node functions/migrateToAdPerformance.js
 */

const admin = require('firebase-admin');
const path = require('path');
const serviceAccount = require(path.join(__dirname, '../bhl-obe-firebase-adminsdk-fbsvc-0a91fc9874.json'));

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateAdPerformanceCosts() {
  console.log('🔄 Starting migration from adPerformanceCosts to adPerformance...');

  const stats = {
    total: 0,
    migrated: 0,
    skipped: 0,
    errors: 0
  };

  try {
    // Step 1: Get all documents from adPerformanceCosts
    console.log('📋 Fetching adPerformanceCosts documents...');
    const costsSnapshot = await db.collection('adPerformanceCosts').get();
    stats.total = costsSnapshot.size;
    console.log(`   Found ${stats.total} documents`);

    if (costsSnapshot.empty) {
      console.log('⚠️ No documents found in adPerformanceCosts collection');
      return stats;
    }

    // Step 2: Process each document
    for (const costDoc of costsSnapshot.docs) {
      try {
        const costData = costDoc.data();
        const costId = costDoc.id;

        // Extract data
        const campaignKey = costData.campaignKey || '';
        const adId = costData.adId || costId;
        const adName = costData.adName || '';
        const campaignName = costData.campaignName || '';
        const budget = costData.budget || 0;
        const linkedProductId = costData.linkedProductId || null;
        const createdBy = costData.createdBy || 'migration';
        const createdAt = costData.createdAt || admin.firestore.Timestamp.now();

        console.log(`\n📝 Processing: ${adName} (${adId})`);

        // Check if ad already exists in adPerformance (from Facebook sync)
        const adPerformanceRef = db.collection('adPerformance').doc(adId);
        const adPerformanceDoc = await adPerformanceRef.get();

        if (adPerformanceDoc.exists) {
          // Ad exists (from Facebook sync), just update adminConfig
          console.log('   ✓ Ad exists in adPerformance, updating adminConfig...');
          
          await adPerformanceRef.update({
            adminConfig: {
              budget: budget,
              linkedProductId: linkedProductId,
              createdBy: createdBy,
              createdAt: createdAt,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            },
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          });

          console.log('   ✅ Updated admin config');
          stats.migrated++;
        } else {
          // Ad doesn't exist yet (no Facebook sync), create placeholder
          console.log('   ℹ️ Ad not in adPerformance, creating placeholder...');
          
          const newAdData = {
            adId: adId,
            adName: adName,
            campaignId: '',
            campaignName: campaignName,
            adSetId: null,
            adSetName: null,
            matchingStatus: 'unmatched',
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            facebookStats: {
              spend: 0,
              impressions: 0,
              reach: 0,
              clicks: 0,
              cpm: 0,
              cpc: 0,
              ctr: 0,
              dateStart: '',
              dateStop: '',
              lastSync: admin.firestore.FieldValue.serverTimestamp()
            },
            adminConfig: {
              budget: budget,
              linkedProductId: linkedProductId,
              createdBy: createdBy,
              createdAt: createdAt,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            }
          };

          await adPerformanceRef.set(newAdData);
          console.log('   ✅ Created placeholder ad');
          stats.migrated++;
        }

      } catch (error) {
        console.error(`   ❌ Error processing ${costDoc.id}:`, error.message);
        stats.errors++;
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('📊 Migration Summary:');
    console.log(`   Total documents: ${stats.total}`);
    console.log(`   Migrated: ${stats.migrated}`);
    console.log(`   Skipped: ${stats.skipped}`);
    console.log(`   Errors: ${stats.errors}`);
    console.log('='.repeat(60));

    if (stats.errors === 0) {
      console.log('\n✅ Migration completed successfully!');
      console.log('\nNext steps:');
      console.log('1. Run Facebook sync to populate facebookStats');
      console.log('2. Run GHL sync to populate ghlStats');
      console.log('3. Verify data in Firebase Console');
      console.log('4. Archive adPerformanceCosts collection (don\'t delete)');
    } else {
      console.log('\n⚠️ Migration completed with errors. Please review the logs.');
    }

    return stats;

  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  }
}

// Run migration
migrateAdPerformanceCosts()
  .then(() => {
    console.log('\n✅ Script completed');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  });

