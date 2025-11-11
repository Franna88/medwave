/**
 * Metrics History Service
 * 
 * Creates weekly and monthly snapshots of campaign metrics for time-series comparisons.
 * Enables fast week-over-week and month-over-month comparisons without re-aggregation.
 */

const admin = require('firebase-admin');

/**
 * Get current week information (Monday-Sunday)
 * @returns {Object} Week info with start/end dates and week number
 */
function getCurrentWeekInfo() {
  const now = new Date();
  const dayOfWeek = now.getDay();
  const diff = dayOfWeek === 0 ? -6 : 1 - dayOfWeek; // Adjust to Monday
  
  const monday = new Date(now);
  monday.setDate(now.getDate() + diff);
  monday.setHours(0, 0, 0, 0);
  
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  sunday.setHours(23, 59, 59, 999);
  
  // ISO week number
  const oneJan = new Date(monday.getFullYear(), 0, 1);
  const numberOfDays = Math.floor((monday - oneJan) / (24 * 60 * 60 * 1000));
  const weekNumber = Math.ceil((numberOfDays + oneJan.getDay() + 1) / 7);
  
  return {
    year: monday.getFullYear(),
    month: monday.getMonth() + 1,
    week: weekNumber,
    weekStart: monday.toISOString().split('T')[0],
    weekEnd: sunday.toISOString().split('T')[0]
  };
}

/**
 * Create a weekly snapshot for a single campaign
 * @param {string} campaignId - The campaign ID
 * @param {Object} weekInfo - Week information
 * @returns {Promise<Object>} Snapshot document
 */
async function createWeeklySnapshotForCampaign(campaignId, weekInfo) {
  const db = admin.firestore();
  
  try {
    // Get current campaign data
    const campaignDoc = await db.collection('campaigns').doc(campaignId).get();
    
    if (!campaignDoc.exists) {
      console.log(`Campaign ${campaignId} not found`);
      return null;
    }
    
    const campaign = campaignDoc.data();
    
    // Create snapshot document ID: campaignId__YYYY-MM-WW
    const snapshotId = `${campaignId}__${weekInfo.year}-${String(weekInfo.month).padStart(2, '0')}-${String(weekInfo.week).padStart(2, '0')}`;
    
    // Build snapshot document
    const snapshotDoc = {
      campaignId: campaignId,
      campaignName: campaign.campaignName || '',
      year: weekInfo.year,
      month: weekInfo.month,
      week: weekInfo.week,
      weekStart: weekInfo.weekStart,
      weekEnd: weekInfo.weekEnd,
      // Copy all metrics
      totalSpend: campaign.totalSpend || 0,
      totalImpressions: campaign.totalImpressions || 0,
      totalClicks: campaign.totalClicks || 0,
      totalReach: campaign.totalReach || 0,
      avgCPM: campaign.avgCPM || 0,
      avgCPC: campaign.avgCPC || 0,
      avgCTR: campaign.avgCTR || 0,
      totalLeads: campaign.totalLeads || 0,
      totalBookings: campaign.totalBookings || 0,
      totalDeposits: campaign.totalDeposits || 0,
      totalCashCollected: campaign.totalCashCollected || 0,
      totalCashAmount: campaign.totalCashAmount || 0,
      totalProfit: campaign.totalProfit || 0,
      cpl: campaign.cpl || 0,
      cpb: campaign.cpb || 0,
      cpa: campaign.cpa || 0,
      roi: campaign.roi || 0,
      leadToBookingRate: campaign.leadToBookingRate || 0,
      bookingToDepositRate: campaign.bookingToDepositRate || 0,
      depositToCashRate: campaign.depositToCashRate || 0,
      adSetCount: campaign.adSetCount || 0,
      adCount: campaign.adCount || 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Save snapshot
    await db.collection('campaignMetricsHistory').doc(snapshotId).set(snapshotDoc, { merge: true });
    
    console.log(`✅ Created weekly snapshot for campaign ${campaignId} (week ${weekInfo.week})`);
    
    return snapshotDoc;
    
  } catch (error) {
    console.error(`Error creating weekly snapshot for campaign ${campaignId}:`, error);
    throw error;
  }
}

/**
 * Create weekly snapshots for all campaigns
 * @returns {Promise<Object>} Summary of snapshots created
 */
async function createWeeklySnapshot() {
  const db = admin.firestore();
  const weekInfo = getCurrentWeekInfo();
  
  console.log(`📊 Creating weekly snapshots for week ${weekInfo.week} (${weekInfo.weekStart} to ${weekInfo.weekEnd})`);
  
  try {
    // Get all campaigns
    const campaignsSnapshot = await db.collection('campaigns').get();
    
    if (campaignsSnapshot.empty) {
      console.log('No campaigns found');
      return { success: true, count: 0 };
    }
    
    let successCount = 0;
    let errorCount = 0;
    
    // Create snapshot for each campaign
    for (const campaignDoc of campaignsSnapshot.docs) {
      try {
        await createWeeklySnapshotForCampaign(campaignDoc.id, weekInfo);
        successCount++;
      } catch (error) {
        console.error(`Error creating snapshot for ${campaignDoc.id}:`, error);
        errorCount++;
      }
    }
    
    console.log(`✅ Created ${successCount} weekly snapshots (${errorCount} errors)`);
    
    return {
      success: true,
      count: successCount,
      errors: errorCount,
      weekInfo: weekInfo
    };
    
  } catch (error) {
    console.error('Error creating weekly snapshots:', error);
    throw error;
  }
}

/**
 * Create monthly snapshot for a single campaign
 * @param {string} campaignId - The campaign ID
 * @returns {Promise<Object>} Snapshot document
 */
async function createMonthlySnapshotForCampaign(campaignId) {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  
  const db = admin.firestore();
  
  try {
    // Get current campaign data
    const campaignDoc = await db.collection('campaigns').doc(campaignId).get();
    
    if (!campaignDoc.exists) {
      console.log(`Campaign ${campaignId} not found`);
      return null;
    }
    
    const campaign = campaignDoc.data();
    
    // Create snapshot document ID: campaignId__YYYY-MM-00 (week 0 indicates monthly)
    const snapshotId = `${campaignId}__${year}-${String(month).padStart(2, '0')}-00`;
    
    // Build snapshot document
    const snapshotDoc = {
      campaignId: campaignId,
      campaignName: campaign.campaignName || '',
      year: year,
      month: month,
      week: 0, // 0 indicates monthly snapshot
      weekStart: `${year}-${String(month).padStart(2, '0')}-01`,
      weekEnd: new Date(year, month, 0).toISOString().split('T')[0], // Last day of month
      // Copy all metrics
      totalSpend: campaign.totalSpend || 0,
      totalImpressions: campaign.totalImpressions || 0,
      totalClicks: campaign.totalClicks || 0,
      totalReach: campaign.totalReach || 0,
      avgCPM: campaign.avgCPM || 0,
      avgCPC: campaign.avgCPC || 0,
      avgCTR: campaign.avgCTR || 0,
      totalLeads: campaign.totalLeads || 0,
      totalBookings: campaign.totalBookings || 0,
      totalDeposits: campaign.totalDeposits || 0,
      totalCashCollected: campaign.totalCashCollected || 0,
      totalCashAmount: campaign.totalCashAmount || 0,
      totalProfit: campaign.totalProfit || 0,
      cpl: campaign.cpl || 0,
      cpb: campaign.cpb || 0,
      cpa: campaign.cpa || 0,
      roi: campaign.roi || 0,
      leadToBookingRate: campaign.leadToBookingRate || 0,
      bookingToDepositRate: campaign.bookingToDepositRate || 0,
      depositToCashRate: campaign.depositToCashRate || 0,
      adSetCount: campaign.adSetCount || 0,
      adCount: campaign.adCount || 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Save snapshot
    await db.collection('campaignMetricsHistory').doc(snapshotId).set(snapshotDoc, { merge: true });
    
    console.log(`✅ Created monthly snapshot for campaign ${campaignId} (${year}-${month})`);
    
    return snapshotDoc;
    
  } catch (error) {
    console.error(`Error creating monthly snapshot for campaign ${campaignId}:`, error);
    throw error;
  }
}

/**
 * Create monthly snapshots for all campaigns
 * @returns {Promise<Object>} Summary of snapshots created
 */
async function createMonthlySnapshot() {
  const db = admin.firestore();
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;
  
  console.log(`📊 Creating monthly snapshots for ${year}-${month}`);
  
  try {
    // Get all campaigns
    const campaignsSnapshot = await db.collection('campaigns').get();
    
    if (campaignsSnapshot.empty) {
      console.log('No campaigns found');
      return { success: true, count: 0 };
    }
    
    let successCount = 0;
    let errorCount = 0;
    
    // Create snapshot for each campaign
    for (const campaignDoc of campaignsSnapshot.docs) {
      try {
        await createMonthlySnapshotForCampaign(campaignDoc.id);
        successCount++;
      } catch (error) {
        console.error(`Error creating snapshot for ${campaignDoc.id}:`, error);
        errorCount++;
      }
    }
    
    console.log(`✅ Created ${successCount} monthly snapshots (${errorCount} errors)`);
    
    return {
      success: true,
      count: successCount,
      errors: errorCount,
      year: year,
      month: month
    };
    
  } catch (error) {
    console.error('Error creating monthly snapshots:', error);
    throw error;
  }
}

/**
 * Get week-over-week comparison for a campaign
 * @param {string} campaignId - The campaign ID
 * @returns {Promise<Object>} Comparison data
 */
async function getWeeklyComparison(campaignId) {
  const db = admin.firestore();
  const weekInfo = getCurrentWeekInfo();
  
  try {
    // Get this week's snapshot
    const thisWeekId = `${campaignId}__${weekInfo.year}-${String(weekInfo.month).padStart(2, '0')}-${String(weekInfo.week).padStart(2, '0')}`;
    const thisWeekDoc = await db.collection('campaignMetricsHistory').doc(thisWeekId).get();
    
    // Get last week's snapshot
    const lastWeek = weekInfo.week - 1;
    const lastWeekId = `${campaignId}__${weekInfo.year}-${String(weekInfo.month).padStart(2, '0')}-${String(lastWeek).padStart(2, '0')}`;
    const lastWeekDoc = await db.collection('campaignMetricsHistory').doc(lastWeekId).get();
    
    if (!thisWeekDoc.exists || !lastWeekDoc.exists) {
      return {
        success: false,
        message: 'Snapshots not found for comparison'
      };
    }
    
    const thisWeek = thisWeekDoc.data();
    const lastWeekData = lastWeekDoc.data();
    
    // Calculate changes
    const changes = {
      spend: thisWeek.totalSpend - lastWeekData.totalSpend,
      leads: thisWeek.totalLeads - lastWeekData.totalLeads,
      bookings: thisWeek.totalBookings - lastWeekData.totalBookings,
      deposits: thisWeek.totalDeposits - lastWeekData.totalDeposits,
      cash: thisWeek.totalCashAmount - lastWeekData.totalCashAmount,
      profit: thisWeek.totalProfit - lastWeekData.totalProfit
    };
    
    // Calculate percentage changes
    const percentChanges = {
      spend: lastWeekData.totalSpend > 0 ? (changes.spend / lastWeekData.totalSpend) * 100 : 0,
      leads: lastWeekData.totalLeads > 0 ? (changes.leads / lastWeekData.totalLeads) * 100 : 0,
      bookings: lastWeekData.totalBookings > 0 ? (changes.bookings / lastWeekData.totalBookings) * 100 : 0,
      deposits: lastWeekData.totalDeposits > 0 ? (changes.deposits / lastWeekData.totalDeposits) * 100 : 0,
      cash: lastWeekData.totalCashAmount > 0 ? (changes.cash / lastWeekData.totalCashAmount) * 100 : 0,
      profit: lastWeekData.totalProfit > 0 ? (changes.profit / lastWeekData.totalProfit) * 100 : 0
    };
    
    return {
      success: true,
      thisWeek: thisWeek,
      lastWeek: lastWeekData,
      changes: changes,
      percentChanges: percentChanges
    };
    
  } catch (error) {
    console.error('Error getting weekly comparison:', error);
    throw error;
  }
}

module.exports = {
  createWeeklySnapshot,
  createMonthlySnapshot,
  createWeeklySnapshotForCampaign,
  createMonthlySnapshotForCampaign,
  getWeeklyComparison,
  getCurrentWeekInfo
};

