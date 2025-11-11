#!/usr/bin/env node
/**
 * Backfill GHL Weekly Data Script
 * One-time script to populate GHL weekly data from existing opportunityStageHistory
 * 
 * Usage: node functions/backfillGHLWeekly.js
 */

const admin = require('firebase-admin');
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

/**
 * Get stage category from stage name
 */
function getStageCategory(stageName) {
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
 * Backfill GHL weekly data for a specific ad
 */
async function backfillGHLWeeklyForAd(adId) {
  try {
    console.log(`   Processing ad: ${adId}`);
    
    // Query opportunityStageHistory for this ad (last 6 months)
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
    
    const opportunitiesSnapshot = await db.collection('opportunityStageHistory')
      .where('facebookAdId', '==', adId)
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(sixMonthsAgo))
      .get();
    
    if (opportunitiesSnapshot.empty) {
      console.log(`      No opportunities found for ad ${adId}`);
      return { success: true, opportunities: 0 };
    }
    
    console.log(`      Found ${opportunitiesSnapshot.size} opportunity records`);
    
    // Group by opportunityId to get latest stage
    const opportunityLatestState = new Map();
    
    opportunitiesSnapshot.forEach(doc => {
      const data = doc.data();
      const oppId = data.opportunityId;
      const timestamp = data.timestamp?.toDate?.() || new Date(data.timestamp);
      
      if (!opportunityLatestState.has(oppId) || 
          timestamp > opportunityLatestState.get(oppId).timestamp) {
        opportunityLatestState.set(oppId, {
          stageCategory: data.stageCategory || getStageCategory(data.newStageName || ''),
          timestamp: timestamp,
          monetaryValue: data.monetaryValue || 0
        });
      }
    });
    
    // Group by week
    const weeklyData = new Map();
    
    for (const [oppId, state] of opportunityLatestState) {
      const weekId = calculateWeekIdFromTimestamp(state.timestamp);
      
      if (!weeklyData.has(weekId)) {
        weeklyData.set(weekId, {
          leads: 0,
          bookedAppointments: 0,
          deposits: 0,
          cashCollected: 0,
          cashAmount: 0
        });
      }
      
      const weekMetrics = weeklyData.get(weekId);
      weekMetrics.leads++;
      
      if (state.stageCategory === 'bookedAppointments') {
        weekMetrics.bookedAppointments++;
      } else if (state.stageCategory === 'deposits') {
        weekMetrics.deposits++;
        weekMetrics.cashAmount += state.monetaryValue || 1500; // Default R1500
      } else if (state.stageCategory === 'cashCollected') {
        weekMetrics.cashCollected++;
        weekMetrics.cashAmount += state.monetaryValue || 1500; // Default R1500
      }
    }
    
    // Write to Firestore
    let batch = db.batch();
    let batchCount = 0;
    
    for (const [weekId, metrics] of weeklyData) {
      const weeklyRef = db.collection('advertData').doc(adId)
        .collection('ghlData').doc('weekly')
        .collection('weekly').doc(weekId);
      
      batch.set(weeklyRef, {
        leads: metrics.leads,
        bookedAppointments: metrics.bookedAppointments,
        deposits: metrics.deposits,
        cashCollected: metrics.cashCollected,
        cashAmount: metrics.cashAmount,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      batchCount++;
      
      // Commit batch every 500 writes
      if (batchCount >= 500) {
        await batch.commit();
        batch = db.batch(); // Create new batch
        batchCount = 0;
      }
    }
    
    // Commit remaining writes
    if (batchCount > 0) {
      await batch.commit();
    }
    
    console.log(`      ✅ Backfilled ${weeklyData.size} weeks`);
    
    return {
      success: true,
      opportunities: opportunityLatestState.size,
      weeks: weeklyData.size
    };
    
  } catch (error) {
    console.error(`      ❌ Error backfilling ad ${adId}:`, error.message);
    return { success: false, error: error.message };
  }
}

async function main() {
  console.log('');
  console.log('='.repeat(80));
  console.log('  GHL WEEKLY DATA BACKFILL');
  console.log('='.repeat(80));
  console.log('');
  console.log('This script will:');
  console.log('1. Query opportunityStageHistory for opportunities with facebookAdId (last 6 months)');
  console.log('2. Group opportunities by week');
  console.log('3. Aggregate metrics per week');
  console.log('4. Write to advertData/{adId}/ghlData/weekly/{weekId}');
  console.log('');
  console.log('⚠️  This may take several minutes...');
  console.log('');
  
  try {
    // Get all adverts
    console.log('🔍 Fetching all adverts from advertData collection...');
    const advertsSnapshot = await db.collection('advertData').get();
    console.log(`✅ Found ${advertsSnapshot.size} adverts`);
    console.log('');
    
    const stats = {
      total: advertsSnapshot.size,
      processed: 0,
      totalOpportunities: 0,
      totalWeeks: 0,
      errors: 0
    };
    
    // Process each advert
    console.log('🔄 Backfilling GHL weekly data...');
    console.log('');
    
    for (const advertDoc of advertsSnapshot.docs) {
      const adId = advertDoc.id;
      const result = await backfillGHLWeeklyForAd(adId);
      
      if (result.success) {
        stats.processed++;
        stats.totalOpportunities += result.opportunities || 0;
        stats.totalWeeks += result.weeks || 0;
      } else {
        stats.errors++;
      }
      
      // Progress update every 10 ads
      if (stats.processed % 10 === 0) {
        console.log(`      Progress: ${stats.processed}/${stats.total} ads processed`);
      }
    }
    
    // Summary
    console.log('');
    console.log('='.repeat(80));
    console.log('  BACKFILL COMPLETED SUCCESSFULLY!');
    console.log('='.repeat(80));
    console.log('');
    console.log('📊 Summary:');
    console.log(`   - Total Adverts: ${stats.total}`);
    console.log(`   - Processed: ${stats.processed}`);
    console.log(`   - Total Opportunities: ${stats.totalOpportunities}`);
    console.log(`   - Total Weeks Populated: ${stats.totalWeeks}`);
    console.log(`   - Errors: ${stats.errors}`);
    console.log('');
    console.log('Next Steps:');
    console.log('1. Verify data in Firebase Console');
    console.log('2. Check that weekIds match between insights and ghlData/weekly');
    console.log('3. Test totals calculation');
    console.log('');
    console.log('='.repeat(80));
    console.log('');
    
    process.exit(0);
    
  } catch (error) {
    console.error('');
    console.error('='.repeat(80));
    console.error('❌ BACKFILL FAILED!');
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
main();

