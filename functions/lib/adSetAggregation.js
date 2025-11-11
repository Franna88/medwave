/**
 * Ad Set Aggregation Service
 * 
 * Aggregates metrics from all ads in an ad set and updates the ad set document
 * with pre-calculated totals for fast loading.
 */

const admin = require('firebase-admin');

/**
 * Aggregate all metrics for an ad set
 * @param {string} adSetId - The ad set ID to aggregate
 * @returns {Promise<Object>} Aggregated metrics
 */
async function aggregateAdSetTotals(adSetId) {
  if (!adSetId) {
    throw new Error('Ad Set ID is required');
  }

  const db = admin.firestore();
  
  try {
    // Get all ads in this ad set
    const adsSnapshot = await db.collection('ads')
      .where('adSetId', '==', adSetId)
      .get();
    
    if (adsSnapshot.empty) {
      console.log(`No ads found for ad set ${adSetId}`);
      return null;
    }

    // Initialize aggregates
    const aggregates = {
      totalSpend: 0,
      totalImpressions: 0,
      totalClicks: 0,
      totalReach: 0,
      totalLeads: 0,
      totalBookings: 0,
      totalDeposits: 0,
      totalCashCollected: 0,
      totalCashAmount: 0,
      adIds: new Set(),
      adSetName: '',
      campaignId: '',
      campaignName: '',
      firstAdDate: null,
      lastAdDate: null
    };

    // Aggregate from all ads
    adsSnapshot.forEach(adDoc => {
      const ad = adDoc.data();
      
      // Store ad set and campaign info from first ad
      if (!aggregates.adSetName && ad.adSetName) {
        aggregates.adSetName = ad.adSetName;
      }
      if (!aggregates.campaignId && ad.campaignId) {
        aggregates.campaignId = ad.campaignId;
      }
      if (!aggregates.campaignName && ad.campaignName) {
        aggregates.campaignName = ad.campaignName;
      }

      // Aggregate Facebook stats
      const fbStats = ad.facebookStats || {};
      aggregates.totalSpend += fbStats.spend || 0;
      aggregates.totalImpressions += fbStats.impressions || 0;
      aggregates.totalClicks += fbStats.clicks || 0;
      aggregates.totalReach += fbStats.reach || 0;

      // Aggregate GHL stats
      const ghlStats = ad.ghlStats || {};
      aggregates.totalLeads += ghlStats.leads || 0;
      aggregates.totalBookings += ghlStats.bookings || 0;
      aggregates.totalDeposits += ghlStats.deposits || 0;
      aggregates.totalCashCollected += ghlStats.cashCollected || 0;
      aggregates.totalCashAmount += ghlStats.cashAmount || 0;

      // Track ads
      aggregates.adIds.add(adDoc.id);

      // Track date range
      if (ad.createdAt) {
        const createdAt = ad.createdAt.toDate ? ad.createdAt.toDate() : new Date(ad.createdAt);
        if (!aggregates.firstAdDate || createdAt < aggregates.firstAdDate) {
          aggregates.firstAdDate = createdAt;
        }
        if (!aggregates.lastAdDate || createdAt > aggregates.lastAdDate) {
          aggregates.lastAdDate = createdAt;
        }
      }
    });

    // Calculate computed metrics
    const totalProfit = aggregates.totalCashAmount - aggregates.totalSpend;
    const cpl = aggregates.totalLeads > 0 ? aggregates.totalSpend / aggregates.totalLeads : 0;
    const cpb = aggregates.totalBookings > 0 ? aggregates.totalSpend / aggregates.totalBookings : 0;
    const cpa = aggregates.totalDeposits > 0 ? aggregates.totalSpend / aggregates.totalDeposits : 0;

    // Calculate averages
    const avgCPM = aggregates.totalImpressions > 0 ? (aggregates.totalSpend / aggregates.totalImpressions) * 1000 : 0;
    const avgCPC = aggregates.totalClicks > 0 ? aggregates.totalSpend / aggregates.totalClicks : 0;
    const avgCTR = aggregates.totalImpressions > 0 ? (aggregates.totalClicks / aggregates.totalImpressions) * 100 : 0;

    // Build ad set document
    const adSetDoc = {
      adSetId: adSetId,
      adSetName: aggregates.adSetName,
      campaignId: aggregates.campaignId,
      campaignName: aggregates.campaignName,
      totalSpend: aggregates.totalSpend,
      totalImpressions: aggregates.totalImpressions,
      totalClicks: aggregates.totalClicks,
      totalReach: aggregates.totalReach,
      avgCPM: avgCPM,
      avgCPC: avgCPC,
      avgCTR: avgCTR,
      totalLeads: aggregates.totalLeads,
      totalBookings: aggregates.totalBookings,
      totalDeposits: aggregates.totalDeposits,
      totalCashCollected: aggregates.totalCashCollected,
      totalCashAmount: aggregates.totalCashAmount,
      totalProfit: totalProfit,
      cpl: cpl,
      cpb: cpb,
      cpa: cpa,
      adCount: aggregates.adIds.size,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      firstAdDate: aggregates.firstAdDate,
      lastAdDate: aggregates.lastAdDate
    };

    // Update ad set document
    await db.collection('adSets').doc(adSetId).set(adSetDoc, { merge: true });

    console.log(`✅ Aggregated ad set ${adSetId}: ${aggregates.adIds.size} ads, ${aggregates.totalLeads} leads`);

    return adSetDoc;

  } catch (error) {
    console.error(`Error aggregating ad set ${adSetId}:`, error);
    throw error;
  }
}

/**
 * Trigger function: Aggregate ad set when an ad is updated
 */
async function onAdUpdate(change, context) {
  const adData = change.after.exists ? change.after.data() : null;
  
  if (!adData || !adData.adSetId) {
    return null;
  }

  const adSetId = adData.adSetId;
  
  try {
    await aggregateAdSetTotals(adSetId);
    return { success: true, adSetId };
  } catch (error) {
    console.error('Error in onAdUpdate trigger:', error);
    return { success: false, error: error.message };
  }
}

module.exports = {
  aggregateAdSetTotals,
  onAdUpdate
};

