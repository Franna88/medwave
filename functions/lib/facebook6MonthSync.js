/**
 * Facebook 6-Month Sync Service
 * Fetches all Facebook ads from the last 6 months with weekly insights
 * Handles rate limits with Firestore-based checkpoint/resume
 */

const axios = require('axios');
const admin = require('firebase-admin');

// Facebook API Configuration
const FACEBOOK_API_VERSION = 'v24.0';
const FACEBOOK_BASE_URL = `https://graph.facebook.com/${FACEBOOK_API_VERSION}`;
const FACEBOOK_AD_ACCOUNT_ID = 'act_220298027464902';
const FACEBOOK_ACCESS_TOKEN = process.env.FACEBOOK_ACCESS_TOKEN || 'EAAc9pw8rgA0BP0S8U9s2cLzSJbCYmJZBKZCTFUNDD2zVXVqkC45q1BIQaPdZAmtXKbZBk6wjprLclIUUafHJ4icQZAXuuePybTL38pNQIcjQQZCbRGGhAtLcLVSGeJP59nMdpt8KNEoMQtvDfZBwBgpLNhQboPpaaeU8fW2rCEEhZA9pRN4RjZAAnwnLqEDaP8Fueo0cZD';

// Rate limit thresholds
const RATE_LIMIT_WARNING_THRESHOLD = 80;
const RATE_LIMIT_STOP_THRESHOLD = 95;

// Checkpoint document path
const CHECKPOINT_DOC_PATH = 'system/facebook6MonthSyncCheckpoint';

/**
 * Calculate week ID from date string (YYYY-MM-DD)
 */
function calculateWeekId(dateStr) {
  const date = new Date(dateStr);
  const dayOfWeek = date.getDay();
  const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  
  const monday = new Date(date);
  monday.setDate(date.getDate() - daysToMonday);
  monday.setHours(0, 0, 0, 0);
  
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  sunday.setHours(23, 59, 59, 999);
  
  const formatDate = (d) => {
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };
  
  return `${formatDate(monday)}_${formatDate(sunday)}`;
}

/**
 * Load checkpoint from Firestore
 */
async function loadCheckpoint() {
  const db = admin.firestore();
  const checkpointRef = db.doc(CHECKPOINT_DOC_PATH);
  const checkpointDoc = await checkpointRef.get();
  
  if (checkpointDoc.exists) {
    const checkpoint = checkpointDoc.data();
    console.log('📋 Checkpoint found:', {
      lastRun: checkpoint.timestamp,
      progress: checkpoint.totalAdsProcessed,
      campaign: `${checkpoint.lastCampaignIndex + 1}/${checkpoint.totalCampaigns}`
    });
    return checkpoint;
  }
  
  return null;
}

/**
 * Save checkpoint to Firestore
 */
async function saveCheckpoint(checkpointData) {
  const db = admin.firestore();
  const checkpointRef = db.doc(CHECKPOINT_DOC_PATH);
  
  checkpointData.timestamp = admin.firestore.FieldValue.serverTimestamp();
  await checkpointRef.set(checkpointData, { merge: true });
}

/**
 * Delete checkpoint from Firestore
 */
async function deleteCheckpoint() {
  const db = admin.firestore();
  const checkpointRef = db.doc(CHECKPOINT_DOC_PATH);
  await checkpointRef.delete();
  console.log('✅ Checkpoint deleted (sync completed)');
}

/**
 * Check rate limit from response headers
 */
function checkRateLimit(response) {
  const headers = response.headers;
  
  let maxUsage = 0;
  let usageType = null;
  
  // Check app-level usage
  if (headers['x-app-usage']) {
    try {
      const appUsage = JSON.parse(headers['x-app-usage']);
      const appPct = appUsage.call_count || 0;
      if (appPct > maxUsage) {
        maxUsage = appPct;
        usageType = 'App';
      }
    } catch (e) {
      // Ignore parse errors
    }
  }
  
  // Check account-level usage
  if (headers['x-ad-account-usage']) {
    try {
      const accountUsage = JSON.parse(headers['x-ad-account-usage']);
      const accountPct = accountUsage.call_count || 0;
      if (accountPct > maxUsage) {
        maxUsage = accountPct;
        usageType = 'Account';
      }
    } catch (e) {
      // Ignore parse errors
    }
  }
  
  const shouldStop = maxUsage >= RATE_LIMIT_STOP_THRESHOLD;
  const shouldWarn = maxUsage >= RATE_LIMIT_WARNING_THRESHOLD;
  
  let warning = null;
  if (shouldStop) {
    warning = `⛔ ${usageType} rate limit at ${maxUsage}% - STOPPING`;
  } else if (shouldWarn) {
    warning = `⚠️  ${usageType} rate limit at ${maxUsage}%`;
  }
  
  return { maxUsage, shouldStop, warning };
}

/**
 * Fetch all campaigns from Facebook
 */
async function fetchCampaigns() {
  const url = `${FACEBOOK_BASE_URL}/${FACEBOOK_AD_ACCOUNT_ID}/campaigns`;
  
  try {
    const response = await axios.get(url, {
      params: {
        fields: 'id,name,status',
        access_token: FACEBOOK_ACCESS_TOKEN,
        limit: 100
      }
    });
    
    const rateLimit = checkRateLimit(response);
    if (rateLimit.warning) {
      console.log(rateLimit.warning);
    }
    
    return {
      campaigns: response.data.data || [],
      shouldStop: rateLimit.shouldStop
    };
  } catch (error) {
    if (error.response?.status === 400) {
      const errorData = error.response.data;
      if (errorData.error?.code === 17) {
        console.log('⛔ RATE LIMIT HIT:', errorData.error.message);
        return { campaigns: null, shouldStop: true };
      }
    }
    throw error;
  }
}

/**
 * Fetch ads for a campaign
 */
async function fetchAdsForCampaign(campaignId) {
  const url = `${FACEBOOK_BASE_URL}/${campaignId}/ads`;
  
  try {
    const response = await axios.get(url, {
      params: {
        fields: 'id,name,adset_id,adset{name},campaign_id',
        access_token: FACEBOOK_ACCESS_TOKEN,
        limit: 100
      }
    });
    
    const rateLimit = checkRateLimit(response);
    if (rateLimit.warning) {
      console.log(rateLimit.warning);
    }
    
    return {
      ads: response.data.data || [],
      shouldStop: rateLimit.shouldStop
    };
  } catch (error) {
    if (error.response?.status === 400) {
      const errorData = error.response.data;
      if (errorData.error?.code === 17) {
        console.log('⛔ RATE LIMIT HIT:', errorData.error.message);
        return { ads: null, shouldStop: true };
      }
    }
    throw error;
  }
}

/**
 * Fetch weekly insights for an ad
 */
async function fetchInsightsForAd(adId, startDate, endDate) {
  const url = `${FACEBOOK_BASE_URL}/${adId}/insights`;
  
  try {
    const response = await axios.get(url, {
      params: {
        time_range: JSON.stringify({ since: startDate, until: endDate }),
        time_increment: 7, // Weekly
        fields: 'spend,impressions,reach,clicks,cpm,cpc,ctr,date_start,date_stop',
        access_token: FACEBOOK_ACCESS_TOKEN,
        limit: 100
      }
    });
    
    const rateLimit = checkRateLimit(response);
    if (rateLimit.warning) {
      console.log(rateLimit.warning);
    }
    
    return {
      insights: response.data.data || [],
      shouldStop: rateLimit.shouldStop
    };
  } catch (error) {
    if (error.response?.status === 400) {
      const errorData = error.response.data;
      if (errorData.error?.code === 17) {
        console.log('⛔ RATE LIMIT HIT:', errorData.error.message);
        return { insights: null, shouldStop: true };
      }
    }
    // Don't throw on insights errors - ad might not have data
    console.log(`⚠️  Error fetching insights for ad ${adId}:`, error.message);
    return { insights: [], shouldStop: false };
  }
}

/**
 * Store ad in Firebase (or update if exists)
 */
async function storeAdInFirebase(adData, campaignName) {
  const db = admin.firestore();
  const adRef = db.collection('advertData').doc(adData.adId);
  
  const existingAd = await adRef.get();
  
  if (existingAd.exists) {
    // Only update timestamp
    await adRef.update({
      lastFacebookSync: admin.firestore.FieldValue.serverTimestamp()
    });
    return true; // Already existed
  } else {
    // Create new ad document
    await adRef.set({
      campaignId: adData.campaignId,
      campaignName: campaignName,
      adSetId: adData.adSetId || '',
      adSetName: adData.adSetName || '',
      adId: adData.adId,
      adName: adData.adName,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      lastFacebookSync: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Create GHL placeholder
    await adRef.collection('ghlWeekly').doc('_placeholder').set({
      note: 'GHL data will be populated from API',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return false; // Newly created
  }
}

/**
 * Store insights in Firebase (skip duplicates)
 */
async function storeInsightsInFirebase(adId, insights) {
  const db = admin.firestore();
  const adRef = db.collection('advertData').doc(adId);
  
  let newWeeks = 0;
  let existingWeeks = 0;
  
  for (const insight of insights) {
    const weekId = calculateWeekId(insight.date_start);
    const insightRef = adRef.collection('insights').doc(weekId);
    
    const existingInsight = await insightRef.get();
    if (existingInsight.exists) {
      existingWeeks++;
      continue;
    }
    
    // Store new insight
    await insightRef.set({
      dateStart: insight.date_start,
      dateStop: insight.date_stop,
      spend: parseFloat(insight.spend || '0'),
      impressions: parseInt(insight.impressions || '0', 10),
      reach: parseInt(insight.reach || '0', 10),
      clicks: parseInt(insight.clicks || '0', 10),
      cpm: parseFloat(insight.cpm || '0'),
      cpc: parseFloat(insight.cpc || '0'),
      ctr: parseFloat(insight.ctr || '0'),
      fetchedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    newWeeks++;
  }
  
  return { newWeeks, existingWeeks };
}

/**
 * Main sync function
 */
async function sync6MonthsFacebookData() {
  console.log('🚀 Starting Facebook 6-Month Sync...');
  
  // Calculate date range (6 months)
  const endDate = new Date();
  const startDate = new Date();
  startDate.setMonth(startDate.getMonth() - 6);
  
  const startDateStr = startDate.toISOString().split('T')[0];
  const endDateStr = endDate.toISOString().split('T')[0];
  
  console.log(`📅 Date range: ${startDateStr} to ${endDateStr}`);
  
  // Load checkpoint
  const checkpoint = await loadCheckpoint();
  
  let startCampaignIdx = 0;
  let startAdIdx = 0;
  let totalAdsProcessed = 0;
  
  if (checkpoint) {
    startCampaignIdx = checkpoint.lastCampaignIndex || 0;
    startAdIdx = (checkpoint.lastAdIndex || -1) + 1;
    totalAdsProcessed = checkpoint.totalAdsProcessed || 0;
    console.log(`✅ Resuming from campaign ${startCampaignIdx + 1}, ad ${startAdIdx + 1}`);
  }
  
  // Fetch campaigns
  console.log('📊 Fetching campaigns...');
  const { campaigns, shouldStop: campaignsRateLimited } = await fetchCampaigns();
  
  if (campaignsRateLimited) {
    console.log('⛔ Rate limit hit while fetching campaigns');
    await saveCheckpoint({
      lastCampaignIndex: startCampaignIdx,
      lastAdIndex: -1,
      totalCampaigns: 0,
      totalAdsProcessed: totalAdsProcessed,
      rateLimitHit: true,
      rateLimitMessage: 'Hit while fetching campaigns'
    });
    return { success: false, rateLimited: true, message: 'Rate limit hit - will retry next hour' };
  }
  
  if (!campaigns || campaigns.length === 0) {
    console.log('❌ No campaigns found');
    return { success: false, message: 'No campaigns found' };
  }
  
  console.log(`✅ Found ${campaigns.length} campaigns`);
  
  // Process campaigns
  let totalNewAds = 0;
  let totalUpdatedAds = 0;
  let totalNewInsights = 0;
  let totalExistingInsights = 0;
  
  for (let campaignIdx = startCampaignIdx; campaignIdx < campaigns.length; campaignIdx++) {
    const campaign = campaigns[campaignIdx];
    console.log(`📱 Campaign [${campaignIdx + 1}/${campaigns.length}]: ${campaign.name}`);
    
    // Fetch ads for this campaign
    const { ads, shouldStop: adsRateLimited } = await fetchAdsForCampaign(campaign.id);
    
    if (adsRateLimited) {
      console.log('⛔ Rate limit hit while fetching ads');
      await saveCheckpoint({
        lastCampaignIndex: campaignIdx,
        lastAdIndex: -1,
        totalCampaigns: campaigns.length,
        totalAdsProcessed: totalAdsProcessed,
        rateLimitHit: true,
        rateLimitMessage: 'Hit while fetching ads'
      });
      return { success: false, rateLimited: true, message: 'Rate limit hit - will retry next hour', progress: { totalAdsProcessed, campaign: campaignIdx + 1 } };
    }
    
    if (!ads || ads.length === 0) {
      console.log('   No ads found');
      continue;
    }
    
    console.log(`   Found ${ads.length} ads`);
    
    // Determine starting ad index
    const adStartIdx = (campaignIdx === startCampaignIdx) ? startAdIdx : 0;
    
    // Process each ad
    for (let adIdx = adStartIdx; adIdx < ads.length; adIdx++) {
      const ad = ads[adIdx];
      const adName = ad.name || 'Unnamed';
      
      console.log(`   Ad [${adIdx + 1}/${ads.length}]: ${adName.substring(0, 50)}`);
      
      // Fetch insights
      const { insights, shouldStop: insightsRateLimited } = await fetchInsightsForAd(ad.id, startDateStr, endDateStr);
      
      if (insightsRateLimited) {
        console.log('⛔ Rate limit hit while fetching insights');
        await saveCheckpoint({
          lastCampaignIndex: campaignIdx,
          lastAdIndex: adIdx,
          totalCampaigns: campaigns.length,
          totalAdsProcessed: totalAdsProcessed,
          rateLimitHit: true,
          rateLimitMessage: 'Hit while fetching insights'
        });
        return { success: false, rateLimited: true, message: 'Rate limit hit - will retry next hour', progress: { totalAdsProcessed, campaign: campaignIdx + 1 } };
      }
      
      console.log(`      ✓ Fetched ${insights ? insights.length : 0} weeks of insights`);
      
      // Store in Firebase
      const adData = {
        adId: ad.id,
        adName: adName,
        campaignId: campaign.id,
        adSetId: ad.adset?.id || '',
        adSetName: ad.adset?.name || ''
      };
      
      const adExisted = await storeAdInFirebase(adData, campaign.name);
      
      if (adExisted) {
        totalUpdatedAds++;
      } else {
        totalNewAds++;
      }
      
      // Store insights
      if (insights && insights.length > 0) {
        const { newWeeks, existingWeeks } = await storeInsightsInFirebase(ad.id, insights);
        totalNewInsights += newWeeks;
        totalExistingInsights += existingWeeks;
        console.log(`      ✓ Stored (${newWeeks} new, ${existingWeeks} existing)`);
      }
      
      totalAdsProcessed++;
      
      // Save checkpoint after each ad
      await saveCheckpoint({
        lastCampaignIndex: campaignIdx,
        lastAdIndex: adIdx,
        totalCampaigns: campaigns.length,
        totalAdsProcessed: totalAdsProcessed,
        rateLimitHit: false,
        rateLimitMessage: null
      });
      
      // Small delay to be nice to the API
      await new Promise(resolve => setTimeout(resolve, 300));
    }
    
    // Reset ad start index for next campaign
    startAdIdx = 0;
  }
  
  // Completion
  console.log('✅ SYNC COMPLETE!');
  console.log(`📊 Summary: ${totalAdsProcessed} ads processed, ${totalNewAds} new, ${totalUpdatedAds} updated`);
  console.log(`   Insights: ${totalNewInsights} new weeks, ${totalExistingInsights} existing weeks`);
  
  // Delete checkpoint
  await deleteCheckpoint();
  
  return {
    success: true,
    stats: {
      totalCampaigns: campaigns.length,
      totalAdsProcessed,
      newAds: totalNewAds,
      updatedAds: totalUpdatedAds,
      newInsights: totalNewInsights,
      existingInsights: totalExistingInsights
    }
  };
}

module.exports = {
  sync6MonthsFacebookData
};

