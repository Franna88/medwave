/**
 * Campaign Aggregation Service
 * 
 * Aggregates metrics from all ads in a campaign and updates the campaign document
 * with pre-calculated totals for fast loading.
 */

const admin = require('firebase-admin');

/**
 * Aggregate all metrics for a campaign
 * @param {string} campaignId - The campaign ID to aggregate
 * @returns {Promise<Object>} Aggregated metrics
 */
async function aggregateCampaignTotals(campaignId) {
  if (!campaignId) {
    throw new Error('Campaign ID is required');
  }

  const db = admin.firestore();
  
  try {
    // Get all ads in this campaign
    const adsSnapshot = await db.collection('ads')
      .where('campaignId', '==', campaignId)
      .get();
    
    if (adsSnapshot.empty) {
      console.log(`No ads found for campaign ${campaignId}`);
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
      adSetIds: new Set(),
      adIds: new Set(),
      campaignName: '',
      firstAdDate: null,
      lastAdDate: null
    };

    // Aggregate from all ads
    adsSnapshot.forEach(adDoc => {
      const ad = adDoc.data();
      
      // Store campaign name from first ad
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

      // Track unique ad sets and ads
      if (ad.adSetId) {
        aggregates.adSetIds.add(ad.adSetId);
      }
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
    const roi = aggregates.totalSpend > 0 ? ((aggregates.totalCashAmount - aggregates.totalSpend) / aggregates.totalSpend) * 100 : 0;

    // Conversion rates
    const leadToBookingRate = aggregates.totalLeads > 0 ? (aggregates.totalBookings / aggregates.totalLeads) * 100 : 0;
    const bookingToDepositRate = aggregates.totalBookings > 0 ? (aggregates.totalDeposits / aggregates.totalBookings) * 100 : 0;
    const depositToCashRate = aggregates.totalDeposits > 0 ? (aggregates.totalCashCollected / aggregates.totalDeposits) * 100 : 0;

    // Calculate averages
    const avgCPM = aggregates.totalImpressions > 0 ? (aggregates.totalSpend / aggregates.totalImpressions) * 1000 : 0;
    const avgCPC = aggregates.totalClicks > 0 ? aggregates.totalSpend / aggregates.totalClicks : 0;
    const avgCTR = aggregates.totalImpressions > 0 ? (aggregates.totalClicks / aggregates.totalImpressions) * 100 : 0;

    // Determine status based on last ad date
    let status = 'UNKNOWN';
    if (aggregates.lastAdDate) {
      const daysSince = (new Date() - aggregates.lastAdDate) / (1000 * 60 * 60 * 24);
      if (daysSince <= 1) {
        status = 'ACTIVE';
      } else if (daysSince <= 7) {
        status = 'RECENT';
      } else {
        status = 'PAUSED';
      }
    }

    // Build campaign document
    const campaignDoc = {
      campaignId: campaignId,
      campaignName: aggregates.campaignName,
      status: status,
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
      roi: roi,
      leadToBookingRate: leadToBookingRate,
      bookingToDepositRate: bookingToDepositRate,
      depositToCashRate: depositToCashRate,
      adSetCount: aggregates.adSetIds.size,
      adCount: aggregates.adIds.size,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      firstAdDate: aggregates.firstAdDate,
      lastAdDate: aggregates.lastAdDate
    };

    // Update campaign document
    await db.collection('campaigns').doc(campaignId).set(campaignDoc, { merge: true });

    console.log(`✅ Aggregated campaign ${campaignId}: ${aggregates.adIds.size} ads, ${aggregates.totalLeads} leads, R${aggregates.totalCashAmount}`);

    return campaignDoc;

  } catch (error) {
    console.error(`Error aggregating campaign ${campaignId}:`, error);
    throw error;
  }
}

/**
 * Trigger function: Aggregate campaign when an ad is updated
 */
async function onAdUpdate(change, context) {
  const adData = change.after.exists ? change.after.data() : null;
  
  if (!adData || !adData.campaignId) {
    return null;
  }

  const campaignId = adData.campaignId;
  
  try {
    await aggregateCampaignTotals(campaignId);
    return { success: true, campaignId };
  } catch (error) {
    console.error('Error in onAdUpdate trigger:', error);
    return { success: false, error: error.message };
  }
}

module.exports = {
  aggregateCampaignTotals,
  onAdUpdate
};

