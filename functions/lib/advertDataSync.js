/**
 * Advert Data Sync Service
 * Manages the new advertData collection structure with synchronized weekly Facebook and GHL data
 */

const axios = require('axios');
const admin = require('firebase-admin');

// Facebook API Configuration
const FACEBOOK_API_VERSION = 'v24.0';
const FACEBOOK_BASE_URL = `https://graph.facebook.com/${FACEBOOK_API_VERSION}`;
const FACEBOOK_AD_ACCOUNT_ID = 'act_220298027464902';
const FACEBOOK_ACCESS_TOKEN = process.env.FACEBOOK_ACCESS_TOKEN || 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD';

// Date calculation helpers
const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Calculate the week ID from a timestamp
 * Returns format: "2024-11-01_2024-11-07"
 */
function calculateWeekIdFromTimestamp(timestamp) {
  const date = new Date(timestamp);
  
  // Get start of week (Monday)
  const dayOfWeek = date.getDay();
  const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1; // Sunday = 0, need to go back 6 days
  
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

/**
 * Get all weeks between two dates
 * Returns array of {weekId, dateStart, dateStop, weekNumber}
 */
function getWeeksBetweenDates(startDate, endDate) {
  const weeks = [];
  let weekNumber = 1;
  
  let currentWeekStart = new Date(startDate);
  const dayOfWeek = currentWeekStart.getDay();
  const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  currentWeekStart.setDate(currentWeekStart.getDate() - daysToMonday);
  currentWeekStart.setHours(0, 0, 0, 0);
  
  while (currentWeekStart <= endDate) {
    const weekEnd = new Date(currentWeekStart);
    weekEnd.setDate(currentWeekStart.getDate() + 6);
    weekEnd.setHours(23, 59, 59, 999);
    
    const weekId = calculateWeekIdFromTimestamp(currentWeekStart);
    
    weeks.push({
      weekId,
      dateStart: new Date(currentWeekStart),
      dateStop: new Date(weekEnd),
      weekNumber
    });
    
    currentWeekStart.setDate(currentWeekStart.getDate() + 7);
    weekNumber++;
  }
  
  return weeks;
}

/**
 * Fetch all Facebook campaigns with ad sets and ads
 */
async function fetchFacebookAdsHierarchy(monthsBack = 6) {
  try {
    console.log(`📋 Fetching Facebook ads hierarchy (last ${monthsBack} months)...`);
    
    const endDate = new Date();
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - monthsBack);
    
    const startDateStr = startDate.toISOString().split('T')[0];
    const endDateStr = endDate.toISOString().split('T')[0];
    
    console.log(`   Date range: ${startDateStr} to ${endDateStr}`);
    
    // Fetch campaigns
    const campaignsUrl = `${FACEBOOK_BASE_URL}/${FACEBOOK_AD_ACCOUNT_ID}/campaigns`;
    const campaignsResponse = await axios.get(campaignsUrl, {
      params: {
        fields: 'id,name',
        access_token: FACEBOOK_ACCESS_TOKEN,
        limit: 100
      }
    });
    
    const campaigns = campaignsResponse.data.data || [];
    console.log(`✅ Fetched ${campaigns.length} campaigns`);
    
    const allAds = [];
    
    // For each campaign, fetch ad sets and ads
    for (const campaign of campaigns) {
      console.log(`   Processing campaign: ${campaign.name}`);
      
      // Fetch ad sets
      const adSetsUrl = `${FACEBOOK_BASE_URL}/${campaign.id}/adsets`;
      const adSetsResponse = await axios.get(adSetsUrl, {
        params: {
          fields: 'id,name',
          access_token: FACEBOOK_ACCESS_TOKEN,
          limit: 100
        }
      });
      
      const adSets = adSetsResponse.data.data || [];
      
      // For each ad set, fetch ads
      for (const adSet of adSets) {
        const adsUrl = `${FACEBOOK_BASE_URL}/${adSet.id}/ads`;
        const adsResponse = await axios.get(adsUrl, {
          params: {
            fields: 'id,name',
            access_token: FACEBOOK_ACCESS_TOKEN,
            limit: 100
          }
        });
        
        const ads = adsResponse.data.data || [];
        
        ads.forEach(ad => {
          allAds.push({
            adId: ad.id,
            adName: ad.name,
            campaignId: campaign.id,
            campaignName: campaign.name,
            adSetId: adSet.id,
            adSetName: adSet.name
          });
        });
      }
    }
    
    console.log(`✅ Total ads found: ${allAds.length}`);
    return allAds;
    
  } catch (error) {
    console.error('❌ Error fetching Facebook ads hierarchy:', error.response?.data || error.message);
    throw error;
  }
}

/**
 * Store advert main document in Firestore
 */
async function storeAdvertInFirestore(adData) {
  const db = admin.firestore();
  const advertRef = db.collection('advertData').doc(adData.adId);
  
  try {
    const docData = {
      campaignId: adData.campaignId,
      campaignName: adData.campaignName,
      adSetId: adData.adSetId || '',
      adSetName: adData.adSetName || '',
      adId: adData.adId,
      adName: adData.adName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      lastFacebookSync: admin.firestore.FieldValue.serverTimestamp(),
      lastGHLSync: null
    };
    
    await advertRef.set(docData, { merge: true });
    return { success: true, adId: adData.adId };
    
  } catch (error) {
    console.error(`❌ Error storing advert ${adData.adId}:`, error.message);
    return { success: false, adId: adData.adId, error: error.message };
  }
}

/**
 * Fetch weekly insights for a specific ad from Facebook
 */
async function fetchWeeklyInsightsForAd(adId, startDate, endDate) {
  try {
    const startDateStr = startDate.toISOString().split('T')[0];
    const endDateStr = endDate.toISOString().split('T')[0];
    
    const url = `${FACEBOOK_BASE_URL}/${adId}/insights`;
    const response = await axios.get(url, {
      params: {
        fields: 'impressions,reach,spend,clicks,cpm,cpc,ctr',
        time_range: JSON.stringify({ since: startDateStr, until: endDateStr }),
        time_increment: 7, // Weekly breakdown
        access_token: FACEBOOK_ACCESS_TOKEN,
        limit: 100
      }
    });
    
    return response.data.data || [];
    
  } catch (error) {
    console.error(`❌ Error fetching weekly insights for ad ${adId}:`, error.response?.data || error.message);
    return [];
  }
}

/**
 * Sync weekly insights for an advert (Facebook data)
 */
async function syncWeeklyInsightsForAdvert(adId, monthsBack = 6) {
  const db = admin.firestore();
  
  try {
    console.log(`📊 Syncing weekly insights for ad ${adId}...`);
    
    const endDate = new Date();
    const startDate = new Date();
    startDate.setMonth(startDate.getMonth() - monthsBack);
    
    // Get week structure
    const weeks = getWeeksBetweenDates(startDate, endDate);
    
    // Fetch insights from Facebook
    const insights = await fetchWeeklyInsightsForAd(adId, startDate, endDate);
    
    if (insights.length === 0) {
      console.log(`   ⚠️ No insights data for ad ${adId}`);
      // Still create empty week documents for structure
      for (const week of weeks) {
        const insightRef = db.collection('advertData').doc(adId)
          .collection('insights').doc(week.weekId);
        
        await insightRef.set({
          weekNumber: week.weekNumber,
          dateStart: admin.firestore.Timestamp.fromDate(week.dateStart),
          dateStop: admin.firestore.Timestamp.fromDate(week.dateStop),
          spend: 0,
          impressions: 0,
          reach: 0,
          clicks: 0,
          cpm: 0,
          cpc: 0,
          ctr: 0,
          fetchedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      }
      return { success: true, weeksStored: weeks.length, hasData: false };
    }
    
    // Map Facebook insights to weeks
    let storedCount = 0;
    for (let i = 0; i < insights.length && i < weeks.length; i++) {
      const insight = insights[i];
      const week = weeks[i];
      
      const insightRef = db.collection('advertData').doc(adId)
        .collection('insights').doc(week.weekId);
      
      await insightRef.set({
        weekNumber: week.weekNumber,
        dateStart: admin.firestore.Timestamp.fromDate(week.dateStart),
        dateStop: admin.firestore.Timestamp.fromDate(week.dateStop),
        spend: parseFloat(insight.spend || '0'),
        impressions: parseInt(insight.impressions || '0', 10),
        reach: parseInt(insight.reach || '0', 10),
        clicks: parseInt(insight.clicks || '0', 10),
        cpm: parseFloat(insight.cpm || '0'),
        cpc: parseFloat(insight.cpc || '0'),
        ctr: parseFloat(insight.ctr || '0'),
        fetchedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      storedCount++;
    }
    
    console.log(`   ✅ Stored ${storedCount} weeks of insights`);
    return { success: true, weeksStored: storedCount, hasData: true };
    
  } catch (error) {
    console.error(`❌ Error syncing weekly insights for ad ${adId}:`, error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Increment GHL weekly metrics for an advert
 */
async function incrementGHLWeeklyMetrics(adId, weekId, stageCategory, monetaryValue) {
  const db = admin.firestore();
  
  try {
    const weeklyRef = db.collection('advertData').doc(adId)
      .collection('ghlWeekly').doc(weekId);
    
    const increments = {
      leads: admin.firestore.FieldValue.increment(1),
      bookedAppointments: admin.firestore.FieldValue.increment(stageCategory === 'bookedAppointments' ? 1 : 0),
      deposits: admin.firestore.FieldValue.increment(stageCategory === 'deposits' ? 1 : 0),
      cashCollected: admin.firestore.FieldValue.increment(stageCategory === 'cashCollected' ? 1 : 0),
      cashAmount: admin.firestore.FieldValue.increment(
        (stageCategory === 'deposits' || stageCategory === 'cashCollected') ? monetaryValue : 0
      ),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await weeklyRef.set(increments, { merge: true });
    return { success: true };
    
  } catch (error) {
    console.error(`❌ Error incrementing GHL weekly metrics:`, error.message);
    return { success: false, error: error.message };
  }
}

/**
 * Get GHL totals by summing all weekly documents
 */
async function getGHLTotals(adId) {
  const db = admin.firestore();
  
  try {
    const weeklySnapshot = await db
      .collection('advertData')
      .doc(adId)
      .collection('ghlWeekly')
      .get();
    
    const totals = {
      leads: 0,
      bookedAppointments: 0,
      deposits: 0,
      cashCollected: 0,
      cashAmount: 0
    };
    
    weeklySnapshot.forEach(doc => {
      const data = doc.data();
      totals.leads += data.leads || 0;
      totals.bookedAppointments += data.bookedAppointments || 0;
      totals.deposits += data.deposits || 0;
      totals.cashCollected += data.cashCollected || 0;
      totals.cashAmount += data.cashAmount || 0;
    });
    
    return totals;
    
  } catch (error) {
    console.error(`❌ Error getting GHL totals for ad ${adId}:`, error.message);
    throw error;
  }
}

/**
 * Fetch and store all Facebook adverts from last N months
 */
async function fetchAndStoreAdvertsFromFacebook(monthsBack = 6) {
  console.log(`🚀 Starting Facebook adverts sync (last ${monthsBack} months)...`);
  
  const stats = {
    totalAds: 0,
    stored: 0,
    insightsSynced: 0,
    errors: 0
  };
  
  try {
    // Fetch all ads
    const ads = await fetchFacebookAdsHierarchy(monthsBack);
    stats.totalAds = ads.length;
    
    // Store each ad and its insights
    for (const ad of ads) {
      console.log(`   Processing ad: ${ad.adName} (${ad.adId})`);
      
      // Store main advert document
      const storeResult = await storeAdvertInFirestore(ad);
      if (storeResult.success) {
        stats.stored++;
      } else {
        stats.errors++;
        continue;
      }
      
      // Sync weekly insights
      const insightsResult = await syncWeeklyInsightsForAdvert(ad.adId, monthsBack);
      if (insightsResult.success) {
        stats.insightsSynced++;
      } else {
        stats.errors++;
      }
    }
    
    console.log('✅ Facebook adverts sync completed!');
    console.log(`   📊 Stats:`);
    console.log(`      - Total Ads: ${stats.totalAds}`);
    console.log(`      - Stored: ${stats.stored}`);
    console.log(`      - Insights Synced: ${stats.insightsSynced}`);
    console.log(`      - Errors: ${stats.errors}`);
    
    return { success: true, stats };
    
  } catch (error) {
    console.error('❌ Facebook adverts sync failed:', error);
    throw error;
  }
}

/**
 * Initialize GHL data structure for all adverts
 * Creates empty weekly documents matching Facebook insights weeks
 */
async function syncAllAdvertsWithGHL() {
  const db = admin.firestore();
  
  try {
    console.log('🔄 Initializing GHL data structure for all adverts...');
    
    const advertsSnapshot = await db.collection('advertData').get();
    console.log(`   Found ${advertsSnapshot.size} adverts`);
    
    let initialized = 0;
    
    for (const advertDoc of advertsSnapshot.docs) {
      const adId = advertDoc.id;
      
      // Get all insights weeks for this ad
      const insightsSnapshot = await db.collection('advertData').doc(adId)
        .collection('insights').get();
      
      // Create matching GHL weekly documents (empty structure)
      for (const insightDoc of insightsSnapshot.docs) {
        const weekId = insightDoc.id;
        const insightData = insightDoc.data();
        
        const weeklyRef = db.collection('advertData').doc(adId)
          .collection('ghlWeekly').doc(weekId);
        
        await weeklyRef.set({
          weekNumber: insightData.weekNumber,
          dateStart: insightData.dateStart,
          dateStop: insightData.dateStop,
          leads: 0,
          bookedAppointments: 0,
          deposits: 0,
          cashCollected: 0,
          cashAmount: 0,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      }
      
      initialized++;
      if (initialized % 10 === 0) {
        console.log(`   Initialized ${initialized} adverts...`);
      }
    }
    
    console.log(`✅ GHL structure initialized for ${initialized} adverts`);
    return { success: true, initialized };
    
  } catch (error) {
    console.error('❌ Error initializing GHL structure:', error);
    throw error;
  }
}

module.exports = {
  calculateWeekIdFromTimestamp,
  getWeeksBetweenDates,
  fetchAndStoreAdvertsFromFacebook,
  storeAdvertInFirestore,
  syncWeeklyInsightsForAdvert,
  incrementGHLWeeklyMetrics,
  getGHLTotals,
  syncAllAdvertsWithGHL
};

