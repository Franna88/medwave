#!/usr/bin/env node
/**
 * Migrate from existing adPerformance to advertData
 * This avoids hitting Facebook API rate limits by using existing data
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

/**
 * Calculate week ID from timestamp
 */
function calculateWeekId(timestamp) {
  const date = new Date(timestamp);
  
  // Get start of week (Monday)
  const dayOfWeek = date.getDay();
  const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  
  const startOfWeek = new Date(date);
  startOfWeek.setDate(date.getDate() - daysToMonday);
  startOfWeek.setHours(0, 0, 0, 0);
  
  // Get end of week (Sunday)
  const endOfWeek = new Date(startOfWeek);
  endOfWeek.setDate(startOfWeek.getDate() + 6);
  endOfWeek.setHours(23, 59, 59, 999);
  
  const formatDate = (d) => {
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };
  
  return `${formatDate(startOfWeek)}_${formatDate(endOfWeek)}`;
}

async function migrateAdPerformanceToAdvertData() {
  console.log('');
  console.log('='.repeat(80));
  console.log('  MIGRATE ADPERFORMANCE TO ADVERTDATA');
  console.log('='.repeat(80));
  console.log('');
  
  try {
    // Get all ads from adPerformance
    console.log('📊 Fetching ads from adPerformance collection...');
    const adPerfSnapshot = await db.collection('adPerformance').get();
    console.log(`✅ Found ${adPerfSnapshot.size} ads`);
    console.log('');
    
    const stats = {
      total: adPerfSnapshot.size,
      migrated: 0,
      errors: 0
    };
    
    // Migrate each ad
    console.log('🔄 Migrating ads to advertData...');
    for (const adDoc of adPerfSnapshot.docs) {
      try {
        const adData = adDoc.data();
        const adId = adDoc.id;
        
        // Create advertData document
        await db.collection('advertData').doc(adId).set({
          campaignId: adData.campaignId || '',
          campaignName: adData.campaignName || '',
          adSetId: adData.adSetId || '',
          adSetName: adData.adSetName || '',
          adId: adId,
          adName: adData.adName || '',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          lastUpdated: adData.lastUpdated || admin.firestore.FieldValue.serverTimestamp(),
          lastFacebookSync: adData.facebookStats?.lastSync || admin.firestore.FieldValue.serverTimestamp(),
          lastGHLSync: adData.ghlStats?.lastSync || null
        }, { merge: true });
        
        stats.migrated++;
        if (stats.migrated % 50 === 0) {
          console.log(`   Migrated ${stats.migrated}/${stats.total} ads...`);
        }
        
      } catch (error) {
        console.error(`   ❌ Error migrating ad ${adDoc.id}:`, error.message);
        stats.errors++;
      }
    }
    
    console.log('');
    console.log('✅ Migration complete!');
    console.log(`   - Total: ${stats.total}`);
    console.log(`   - Migrated: ${stats.migrated}`);
    console.log(`   - Errors: ${stats.errors}`);
    console.log('');
    console.log('='.repeat(80));
    console.log('');
    
    return stats;
    
  } catch (error) {
    console.error('❌ Migration failed:', error.message);
    throw error;
  }
}

async function main() {
  try {
    await migrateAdPerformanceToAdvertData();
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();

