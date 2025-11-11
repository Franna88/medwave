/**
 * Facebook Ads Sync Service
 * Fetches ads from Facebook Marketing API and stores them in Firebase
 */

const axios = require('axios');
const admin = require('firebase-admin');

// Facebook API Configuration
const FACEBOOK_API_VERSION = 'v24.0';
const FACEBOOK_BASE_URL = `https://graph.facebook.com/${FACEBOOK_API_VERSION}`;
const FACEBOOK_AD_ACCOUNT_ID = 'act_220298027464902';
const FACEBOOK_ACCESS_TOKEN = process.env.FACEBOOK_ACCESS_TOKEN || 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD';

// Date preset for fetching insights (last 30 days)
const DEFAULT_DATE_PRESET = 'last_30d';

/**
 * Normalize ad/campaign name for matching
 * Removes special characters, converts to lowercase, normalizes whitespace
 */
function normalizeAdName(name) {
  if (!name) return '';
  return name
    .toLowerCase()
    .replace(/[^\w\s]/g, '') // Remove special characters
    .replace(/\s+/g, ' ')    // Normalize whitespace
    .trim();
}

/**
 * Fetch all campaigns from Facebook with insights
 */
async function fetchFacebookCampaigns(datePreset = DEFAULT_DATE_PRESET) {
  try {
    console.log('📋 Fetching Facebook campaigns...');
    
    const url = `${FACEBOOK_BASE_URL}/${FACEBOOK_AD_ACCOUNT_ID}/campaigns`;
    const response = await axios.get(url, {
      params: {
        fields: 'id,name,insights{impressions,reach,spend,clicks,cpm,cpc,ctr,date_start,date_stop}',
        date_preset: datePreset,
        access_token: FACEBOOK_ACCESS_TOKEN,
        limit: 100
      }
    });

    const campaigns = response.data.data || [];
    console.log(`✅ Fetched ${campaigns.length} campaigns`);
    
    return campaigns;
  } catch (error) {
    console.error('❌ Error fetching Facebook campaigns:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Fetch all ad sets for a campaign
 */
async function fetchAdSetsForCampaign(campaignId, datePreset = DEFAULT_DATE_PRESET) {
  try {
    const url = `${FACEBOOK_BASE_URL}/${campaignId}/adsets`;
    const response = await axios.get(url, {
      params: {
        fields: 'id,name,campaign_id,campaign{name},insights{impressions,reach,spend,clicks,cpm,cpc,ctr,date_start,date_stop}',
        date_preset: datePreset,
        access_token: FACEBOOK_ACCESS_TOKEN,
        limit: 100
      }
    });

    return response.data.data || [];
  } catch (error) {
    console.error(`❌ Error fetching ad sets for campaign ${campaignId}:`, error.response?.data || error.message);
    return [];
  }
}

/**
 * Fetch all ads for an ad set
 */
async function fetchAdsForAdSet(adSetId, datePreset = DEFAULT_DATE_PRESET) {
  try {
    const url = `${FACEBOOK_BASE_URL}/${adSetId}/ads`;
    const response = await axios.get(url, {
      params: {
        fields: 'id,name,adset_id,adset{name},campaign_id,insights{impressions,reach,spend,clicks,cpm,cpc,ctr,date_start,date_stop}',
        date_preset: datePreset,
        access_token: FACEBOOK_ACCESS_TOKEN,
        limit: 100
      }
    });

    return response.data.data || [];
  } catch (error) {
    console.error(`❌ Error fetching ads for ad set ${adSetId}:`, error.response?.data || error.message);
    return [];
  }
}

/**
 * Parse insights from Facebook API response
 */
function parseInsights(insights) {
  if (!insights || !insights.data || insights.data.length === 0) {
    return {
      spend: 0,
      impressions: 0,
      reach: 0,
      clicks: 0,
      cpm: 0,
      cpc: 0,
      ctr: 0,
      dateStart: '',
      dateStop: ''
    };
  }

  const insight = insights.data[0];
  return {
    spend: parseFloat(insight.spend || '0'),
    impressions: parseInt(insight.impressions || '0', 10),
    reach: parseInt(insight.reach || '0', 10),
    clicks: parseInt(insight.clicks || '0', 10),
    cpm: parseFloat(insight.cpm || '0'),
    cpc: parseFloat(insight.cpc || '0'),
    ctr: parseFloat(insight.ctr || '0'),
    dateStart: insight.date_start || '',
    dateStop: insight.date_stop || ''
  };
}

/**
 * Parse weekly insights from Facebook API response
 * Returns an array of weekly data points
 */
function parseWeeklyInsights(insights) {
  if (!insights || !insights.data || insights.data.length === 0) {
    return [];
  }

  return insights.data.map((insight, index) => ({
    weekNumber: index + 1,
    spend: parseFloat(insight.spend || '0'),
    impressions: parseInt(insight.impressions || '0', 10),
    reach: parseInt(insight.reach || '0', 10),
    clicks: parseInt(insight.clicks || '0', 10),
    cpm: parseFloat(insight.cpm || '0'),
    cpc: parseFloat(insight.cpc || '0'),
    ctr: parseFloat(insight.ctr || '0'),
    dateStart: insight.date_start || '',
    dateStop: insight.date_stop || ''
  }));
}

/**
 * Fetch weekly insights for a specific ad
 * @param {string} adId - Facebook Ad ID
 * @param {string} startDate - Start date in YYYY-MM-DD format
 * @param {string} endDate - End date in YYYY-MM-DD format
 * @returns {Promise<Array>} Array of weekly insights
 */
async function fetchWeeklyInsights(adId, startDate, endDate) {
  try {
    console.log(`📊 Fetching weekly insights for ad ${adId} (${startDate} to ${endDate})...`);
    
    const url = `${FACEBOOK_BASE_URL}/${adId}/insights`;
    const response = await axios.get(url, {
      params: {
        fields: 'impressions,reach,spend,clicks,cpm,cpc,ctr',
        time_range: JSON.stringify({ since: startDate, until: endDate }),
        time_increment: 7, // Weekly breakdown
        access_token: FACEBOOK_ACCESS_TOKEN,
        limit: 100
      }
    });

    const weeklyData = parseWeeklyInsights(response.data);
    console.log(`   ✅ Fetched ${weeklyData.length} weeks of data`);
    
    return weeklyData;
  } catch (error) {
    console.error(`❌ Error fetching weekly insights for ad ${adId}:`, error.response?.data || error.message);
    return [];
  }
}

/**
 * Store weekly insights in Firestore subcollection
 * @param {string} adId - Facebook Ad ID
 * @param {Array} weeklyData - Array of weekly insights
 * @returns {Promise<Object>} Result with success status and stats
 */
async function storeWeeklyInsightsInFirestore(adId, weeklyData) {
  const db = admin.firestore();
  const weeklyInsightsRef = db.collection('adPerformance').doc(adId).collection('weeklyInsights');

  try {
    let stored = 0;
    let errors = 0;
    let createdMonth = null;

    // Determine month from first week's data
    if (weeklyData.length > 0) {
      createdMonth = weeklyData[0].dateStart.substring(0, 7); // "2025-10"
    }

    for (const week of weeklyData) {
      try {
        // Use date range as document ID for easy querying
        const weekId = `${week.dateStart}_${week.dateStop}`;
        
        // Store in OLD structure (for backward compatibility)
        await weeklyInsightsRef.doc(weekId).set({
          adId: adId,
          weekNumber: week.weekNumber,
          dateStart: admin.firestore.Timestamp.fromDate(new Date(week.dateStart)),
          dateStop: admin.firestore.Timestamp.fromDate(new Date(week.dateStop)),
          spend: week.spend,
          impressions: week.impressions,
          reach: week.reach,
          clicks: week.clicks,
          cpm: week.cpm,
          cpc: week.cpc,
          ctr: week.ctr,
          fetchedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        // ALSO store in NEW month-first structure
        if (createdMonth) {
          const newInsightsRef = db.collection('advertData')
            .doc(createdMonth)
            .collection('ads')
            .doc(adId)
            .collection('insights')
            .doc(weekId);
          
          await newInsightsRef.set({
            dateStart: week.dateStart,
            dateStop: week.dateStop,
            spend: week.spend,
            impressions: week.impressions,
            reach: week.reach,
            clicks: week.clicks,
            cpm: week.cpm,
            cpc: week.cpc,
            ctr: week.ctr,
            fetchedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
        }

        stored++;
      } catch (error) {
        console.error(`   ⚠️ Error storing week ${week.weekNumber}:`, error.message);
        errors++;
      }
    }

    return {
      success: true,
      adId: adId,
      stored: stored,
      errors: errors
    };
  } catch (error) {
    console.error(`❌ Error storing weekly insights for ad ${adId}:`, error.message);
    return {
      success: false,
      adId: adId,
      error: error.message
    };
  }
}

/**
 * Sync weekly insights for a single ad
 * @param {string} adId - Facebook Ad ID
 * @param {number} monthsBack - Number of months to fetch (default: 6)
 * @returns {Promise<Object>} Result with success status
 */
async function syncWeeklyInsightsForAd(adId, monthsBack = 6) {
  try {
    // Calculate date range
    const endDate = new Date();
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - monthsBack);

    const startDateStr = startDate.toISOString().split('T')[0];
    const endDateStr = endDate.toISOString().split('T')[0];

    // Fetch weekly data from Facebook API
    const weeklyData = await fetchWeeklyInsights(adId, startDateStr, endDateStr);

    if (weeklyData.length === 0) {
      return {
        success: true,
        adId: adId,
        message: 'No weekly data available',
        weeksStored: 0
      };
    }

    // Store in Firestore
    const result = await storeWeeklyInsightsInFirestore(adId, weeklyData);

    return {
      success: result.success,
      adId: adId,
      weeksStored: result.stored || 0,
      errors: result.errors || 0
    };
  } catch (error) {
    console.error(`❌ Error syncing weekly insights for ad ${adId}:`, error.message);
    return {
      success: false,
      adId: adId,
      error: error.message
    };
  }
}

/**
 * Update or create ad performance record in Firestore
 * Also writes to new advertData collection
 */
async function updateAdPerformanceInFirestore(adData) {
  const db = admin.firestore();
  const adRef = db.collection('adPerformance').doc(adData.adId);

  try {
    // Get existing document to preserve GHL stats and admin config
    const existingDoc = await adRef.get();
    const existingData = existingDoc.exists ? existingDoc.data() : {};

    // Prepare Facebook stats
    const facebookStats = {
      spend: adData.spend,
      impressions: adData.impressions,
      reach: adData.reach,
      clicks: adData.clicks,
      cpm: adData.cpm,
      cpc: adData.cpc,
      ctr: adData.ctr,
      dateStart: adData.dateStart,
      dateStop: adData.dateStop,
      lastSync: admin.firestore.FieldValue.serverTimestamp()
    };

    // Determine matching status
    let matchingStatus = 'unmatched';
    if (existingData.ghlStats && existingData.ghlStats.leads > 0) {
      matchingStatus = 'matched';
    }

    // Prepare document data
    const docData = {
      adId: adData.adId,
      adName: adData.adName,
      campaignId: adData.campaignId,
      campaignName: adData.campaignName,
      adSetId: adData.adSetId || null,
      adSetName: adData.adSetName || null,
      matchingStatus: matchingStatus,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      facebookStats: facebookStats
    };

    // Preserve existing GHL stats and admin config
    if (existingData.ghlStats) {
      docData.ghlStats = existingData.ghlStats;
    }
    if (existingData.adminConfig) {
      docData.adminConfig = existingData.adminConfig;
    }

    // Update or create document (OLD collection - for backward compatibility)
    await adRef.set(docData, { merge: true });

    // ALSO write to NEW month-first advertData collection
    // Determine month from dateStart
    let createdMonth = null;
    if (adData.dateStart) {
      createdMonth = adData.dateStart.substring(0, 7); // "2025-10"
    }
    
    if (createdMonth) {
      const monthRef = db.collection('advertData').doc(createdMonth);
      const adRef = monthRef.collection('ads').doc(adData.adId);
      
      await adRef.set({
        campaignId: adData.campaignId,
        campaignName: adData.campaignName,
        adSetId: adData.adSetId || '',
        adSetName: adData.adSetName || '',
        adId: adData.adId,
        adName: adData.adName,
        createdMonth: createdMonth,
        hasInsights: true,
        hasGHLData: false, // Will be set by GHL sync
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        lastFacebookSync: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      // Update month summary
      await monthRef.set({
        totalAds: admin.firestore.FieldValue.increment(1),
        adsWithInsights: admin.firestore.FieldValue.increment(1),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }

    return {
      success: true,
      adId: adData.adId,
      adName: adData.adName
    };
  } catch (error) {
    console.error(`❌ Error updating ad ${adData.adId} in Firestore:`, error.message);
    return {
      success: false,
      adId: adData.adId,
      error: error.message
    };
  }
}

/**
 * Main sync function: Fetch all Facebook ads and store in Firestore
 */
async function syncFacebookAdsToFirebase(datePreset = DEFAULT_DATE_PRESET) {
  console.log('🚀 Starting Facebook Ads sync to Firebase...');
  console.log(`   Date range: ${datePreset}`);

  const stats = {
    totalCampaigns: 0,
    totalAdSets: 0,
    totalAds: 0,
    synced: 0,
    errors: 0,
    errorDetails: []
  };

  try {
    // Step 1: Fetch all campaigns
    const campaigns = await fetchFacebookCampaigns(datePreset);
    stats.totalCampaigns = campaigns.length;

    // Step 2: For each campaign, fetch ad sets and ads
    for (const campaign of campaigns) {
      console.log(`📊 Processing campaign: ${campaign.name} (${campaign.id})`);

      try {
        // Fetch ad sets for this campaign
        const adSets = await fetchAdSetsForCampaign(campaign.id, datePreset);
        stats.totalAdSets += adSets.length;

        console.log(`   └─ Found ${adSets.length} ad sets`);

        // For each ad set, fetch ads
        for (const adSet of adSets) {
          try {
            const ads = await fetchAdsForAdSet(adSet.id, datePreset);
            stats.totalAds += ads.length;

            console.log(`      └─ Ad Set: ${adSet.name} → ${ads.length} ads`);

            // Process each ad
            for (const ad of ads) {
              const insights = parseInsights(ad.insights);

              const adData = {
                adId: ad.id,
                adName: ad.name,
                campaignId: campaign.id,
                campaignName: campaign.name,
                adSetId: adSet.id,
                adSetName: adSet.name,
                ...insights
              };

              // Update in Firestore
              const result = await updateAdPerformanceInFirestore(adData);
              
              if (result.success) {
                stats.synced++;
                
                // Also sync recent weekly data (last 4 weeks) for this ad
                try {
                  await syncWeeklyInsightsForAd(ad.id, 1); // 1 month = ~4 weeks
                } catch (weeklyError) {
                  console.error(`   ⚠️ Failed to sync weekly data for ad ${ad.id}:`, weeklyError.message);
                }
              } else {
                stats.errors++;
                stats.errorDetails.push({
                  adId: result.adId,
                  error: result.error
                });
              }
            }
          } catch (error) {
            console.error(`   ⚠️ Error processing ad set ${adSet.id}:`, error.message);
            stats.errors++;
          }
        }
      } catch (error) {
        console.error(`⚠️ Error processing campaign ${campaign.id}:`, error.message);
        stats.errors++;
      }
    }

    console.log('✅ Facebook Ads sync completed!');
    console.log(`   📊 Stats:`);
    console.log(`      - Campaigns: ${stats.totalCampaigns}`);
    console.log(`      - Ad Sets: ${stats.totalAdSets}`);
    console.log(`      - Total Ads: ${stats.totalAds}`);
    console.log(`      - Synced: ${stats.synced}`);
    console.log(`      - Errors: ${stats.errors}`);

    return {
      success: true,
      message: 'Facebook Ads sync completed successfully',
      stats: stats
    };
  } catch (error) {
    console.error('❌ Facebook Ads sync failed:', error);
    throw error;
  }
}

module.exports = {
  syncFacebookAdsToFirebase,
  normalizeAdName,
  fetchWeeklyInsights,
  storeWeeklyInsightsInFirestore,
  syncWeeklyInsightsForAd
};

