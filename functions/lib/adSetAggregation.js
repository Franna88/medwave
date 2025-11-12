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

/**
 * Aggregate ad set metrics by month
 * Creates a monthlyTotals map with month-specific totals
 * @param {string} adSetId - The ad set ID to aggregate
 * @returns {Promise<Object>} Monthly aggregated metrics
 */
async function aggregateAdSetMonthlyTotals(adSetId) {
  if (!adSetId) {
    throw new Error('Ad Set ID is required');
  }

  const db = admin.firestore();
  
  try {
    console.log(`📊 Aggregating monthly totals for ad set ${adSetId}...`);
    
    // Get all ads in this ad set
    const adsSnapshot = await db.collection('ads')
      .where('adSetId', '==', adSetId)
      .get();
    
    if (adsSnapshot.empty) {
      console.log(`No ads found for ad set ${adSetId}`);
      return null;
    }

    // Group ads by month based on firstInsightDate
    const monthlyData = {};
    
    adsSnapshot.forEach(adDoc => {
      const ad = adDoc.data();
      
      // Get the month from firstInsightDate or lastInsightDate
      let month = null;
      if (ad.firstInsightDate) {
        month = ad.firstInsightDate.substring(0, 7); // "2025-11"
      } else if (ad.lastInsightDate) {
        month = ad.lastInsightDate.substring(0, 7);
      }
      
      if (!month) {
        return; // Skip ads without dates
      }
      
      // Initialize month if not exists
      if (!monthlyData[month]) {
        monthlyData[month] = {
          spend: 0,
          impressions: 0,
          clicks: 0,
          reach: 0,
          leads: 0,
          bookings: 0,
          deposits: 0,
          cashCollected: 0,
          cashAmount: 0,
          adCount: 0
        };
      }
      
      // Aggregate Facebook stats
      const fbStats = ad.facebookStats || {};
      monthlyData[month].spend += fbStats.spend || 0;
      monthlyData[month].impressions += fbStats.impressions || 0;
      monthlyData[month].clicks += fbStats.clicks || 0;
      monthlyData[month].reach += fbStats.reach || 0;
      
      // Aggregate GHL stats
      const ghlStats = ad.ghlStats || {};
      monthlyData[month].leads += ghlStats.leads || 0;
      monthlyData[month].bookings += ghlStats.bookings || 0;
      monthlyData[month].deposits += ghlStats.deposits || 0;
      monthlyData[month].cashCollected += ghlStats.cashCollected || 0;
      monthlyData[month].cashAmount += ghlStats.cashAmount || 0;
      
      monthlyData[month].adCount++;
    });
    
    // Calculate computed metrics for each month
    const monthlyTotals = {};
    
    for (const [month, data] of Object.entries(monthlyData)) {
      const profit = data.cashAmount - data.spend;
      const cpl = data.leads > 0 ? data.spend / data.leads : 0;
      const cpb = data.bookings > 0 ? data.spend / data.bookings : 0;
      const cpa = data.deposits > 0 ? data.spend / data.deposits : 0;
      const cpm = data.impressions > 0 ? (data.spend / data.impressions) * 1000 : 0;
      const cpc = data.clicks > 0 ? data.spend / data.clicks : 0;
      const ctr = data.impressions > 0 ? (data.clicks / data.impressions) * 100 : 0;
      
      monthlyTotals[month] = {
        spend: data.spend,
        impressions: data.impressions,
        clicks: data.clicks,
        reach: data.reach,
        leads: data.leads,
        bookings: data.bookings,
        deposits: data.deposits,
        cashCollected: data.cashCollected,
        cashAmount: data.cashAmount,
        profit: profit,
        cpl: cpl,
        cpb: cpb,
        cpa: cpa,
        cpm: cpm,
        cpc: cpc,
        ctr: ctr,
        adCount: data.adCount
      };
    }
    
    // Update ad set document with monthly totals
    await db.collection('adSets').doc(adSetId).update({
      monthlyTotals: monthlyTotals,
      lastMonthlyAggregation: admin.firestore.FieldValue.serverTimestamp()
    });
    
    const monthCount = Object.keys(monthlyTotals).length;
    console.log(`✅ Aggregated ${monthCount} months for ad set ${adSetId}`);
    
    return monthlyTotals;
    
  } catch (error) {
    console.error(`Error aggregating monthly totals for ad set ${adSetId}:`, error);
    throw error;
  }
}

/**
 * Aggregate ad set totals including monthly breakdown
 * This combines lifetime totals with monthly totals
 * @param {string} adSetId - The ad set ID to aggregate
 * @returns {Promise<Object>} Aggregated metrics with monthly breakdown
 */
async function aggregateAdSetWithMonthly(adSetId) {
  // First, aggregate lifetime totals
  await aggregateAdSetTotals(adSetId);
  
  // Then, aggregate monthly totals
  await aggregateAdSetMonthlyTotals(adSetId);
  
  return { success: true, adSetId };
}

module.exports = {
  aggregateAdSetTotals,
  aggregateAdSetMonthlyTotals,
  aggregateAdSetWithMonthly,
  onAdUpdate
};

