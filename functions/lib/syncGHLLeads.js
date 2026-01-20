/**
 * GHL Leads Sync Module
 * Fetches new leads from GoHighLevel (Andries and Davide pipelines)
 * and stores them in Firebase leads collection with deduplication
 */

const admin = require('firebase-admin');
const axios = require('axios');

// GHL API Configuration
const GHL_BASE_URL = 'https://services.leadconnectorhq.com';
const GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw';
const GHL_API_VERSION = '2021-07-28';

// Pipeline IDs (Only Andries and Davide)
const ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g';
const DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz';

// Baseline timestamp: December 11, 2025 00:00:00 UTC
// This is when the last manual sync was run
const BASELINE_TIMESTAMP = new Date('2025-12-11T00:00:00.000Z');

/**
 * Get GHL API headers
 */
function getGHLHeaders(apiKey) {
  return {
    'Authorization': `Bearer ${apiKey}`,
    'Version': GHL_API_VERSION,
    'Content-Type': 'application/json'
  };
}

/**
 * Get last sync timestamp from Firebase syncMetadata collection
 * Returns baseline timestamp (Dec 11, 2025) if no sync metadata exists
 */
async function getLastSyncTimestamp(db) {
  try {
    const syncDoc = await db.collection('syncMetadata').doc('ghlLeads').get();
    
    if (!syncDoc.exists) {
      console.log('📅 No previous sync found, using baseline: December 11, 2025');
      return BASELINE_TIMESTAMP;
    }
    
    const data = syncDoc.data();
    const lastSync = data.lastGHLLeadSync;
    
    if (lastSync) {
      // Handle both Timestamp and string formats
      if (lastSync.toDate) {
        return lastSync.toDate();
      } else if (typeof lastSync === 'string') {
        return new Date(lastSync);
      }
      return new Date(lastSync);
    }
    
    return BASELINE_TIMESTAMP;
  } catch (error) {
    console.error('⚠️ Error reading sync timestamp, using baseline:', error);
    return BASELINE_TIMESTAMP;
  }
}

/**
 * Split full name into first and last name
 */
function splitName(fullName) {
  if (!fullName) {
    return ['', ''];
  }
  
  const parts = fullName.trim().split(/\s+/);
  if (parts.length === 1) {
    return [parts[0], ''];
  }
  
  return [parts[0], parts.slice(1).join(' ')];
}

/**
 * Extract UTM parameters from GHL attributions array
 * Ported from Python logic
 */
function extractUTMFromAttributions(attributions) {
  if (!attributions || !Array.isArray(attributions) || attributions.length === 0) {
    return {
      utmSource: null,
      utmMedium: null,
      utmCampaign: null,
      utmCampaignId: null,
      utmAdset: null,
      utmAdsetId: null,
      utmAd: null,
      utmAdId: null,
      fbclid: null
    };
  }
  
  // Get the last attribution (most recent) - check for isLast flag first
  let lastAttr = null;
  for (const attr of attributions) {
    if (attr.isLast) {
      lastAttr = attr;
      break;
    }
  }
  
  // If no isLast found, use the last item in array
  if (!lastAttr && attributions.length > 0) {
    lastAttr = attributions[attributions.length - 1];
  }
  
  if (!lastAttr) {
    return {
      utmSource: null,
      utmMedium: null,
      utmCampaign: null,
      utmCampaignId: null,
      utmAdset: null,
      utmAdsetId: null,
      utmAd: null,
      utmAdId: null,
      fbclid: null
    };
  }
  
  // Extract UTM fields directly from attribution object
  // Map GHL attribution fields to Lead model fields
  return {
    utmSource: lastAttr.utmSource || null,
    utmMedium: lastAttr.utmMedium || null,
    utmCampaign: lastAttr.utmCampaign || null,
    utmCampaignId: lastAttr.utmCampaignId || null,
    utmAdset: lastAttr.utmMedium || null, // Ad set name is in utmMedium
    utmAdsetId: lastAttr.utmAdSetId || lastAttr.fbc_id || lastAttr.fbcId || null,
    utmAd: lastAttr.utmContent || null, // Ad name is in utmContent
    utmAdId: lastAttr.utmAdId || lastAttr.h_ad_id || lastAttr.hAdId || lastAttr.adId || null,
    fbclid: lastAttr.fbclid || null
  };
}

/**
 * Extract lead data from GHL opportunity
 */
function extractLeadData(opportunity, contact) {
  const [firstName, lastName] = splitName(contact?.name || opportunity?.name || '');
  const utm = extractUTMFromAttributions(opportunity.attributions || []);
  
  // Get current timestamp for use in arrays (cannot use FieldValue.serverTimestamp() in arrays)
  const now = new Date();
  const nowTimestamp = admin.firestore.Timestamp.fromDate(now);
  
  // Parse createdAt timestamp
  let createdAt;
  if (opportunity.createdAt) {
    createdAt = admin.firestore.Timestamp.fromDate(new Date(opportunity.createdAt));
  } else {
    createdAt = nowTimestamp;
  }
  
  return {
    firstName: firstName,
    lastName: lastName,
    email: contact?.email || '',
    phone: contact?.phone || '',
    source: opportunity.source || 'ghl',
    channelId: 'new_leads',
    currentStage: 'new_lead',
    createdAt: createdAt,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    stageEnteredAt: admin.firestore.FieldValue.serverTimestamp(),
    stageHistory: [{
      stage: 'new_lead',
      enteredAt: nowTimestamp, // Use actual Timestamp, not FieldValue (can't use FieldValue in arrays)
      exitedAt: null,
      note: null
    }],
    notes: [],
    createdBy: 'ghl_sync_cron',
    createdByName: 'GHL Sync Cron Job',
    ghlOpportunityId: opportunity.id || null,
    // UTM fields from attributions
    utmSource: utm.utmSource,
    utmMedium: utm.utmMedium,
    utmCampaign: utm.utmCampaign,
    utmCampaignId: utm.utmCampaignId,
    utmAdset: utm.utmAdset,
    utmAdsetId: utm.utmAdsetId,
    utmAd: utm.utmAd,
    utmAdId: utm.utmAdId,
    fbclid: utm.fbclid
  };
}

/**
 * Check if lead already exists in Firebase
 */
async function checkLeadExists(db, contactId) {
  try {
    const leadDoc = await db.collection('leads').doc(contactId).get();
    return leadDoc.exists;
  } catch (error) {
    console.error(`⚠️ Error checking if lead exists (${contactId}):`, error);
    return false; // Assume doesn't exist on error, will be caught during write
  }
}

/**
 * Create lead in Firebase
 */
async function createLeadInFirebase(db, contactId, leadData) {
  try {
    await db.collection('leads').doc(contactId).set(leadData);
    return true;
  } catch (error) {
    console.error(`❌ Error creating lead (${contactId}):`, error);
    return false;
  }
}

/**
 * Fetch opportunities from GHL API since a given timestamp
 * Handles pagination and rate limiting
 */
async function fetchOpportunitiesSinceTimestamp(timestamp, pipelineIds, apiKey) {
  const allOpportunities = [];
  const url = `${GHL_BASE_URL}/opportunities/search`;
  let page = 1;
  const limit = 100;
  const maxPages = 1000; // Safety limit
  
  // Convert timestamp to ISO string for filtering
  const sinceDate = timestamp.toISOString();
  
  console.log(`📊 Fetching opportunities created after: ${sinceDate}`);
  
  while (page <= maxPages) {
    try {
      const params = {
        location_id: GHL_LOCATION_ID,
        limit: limit,
        page: page
      };
      
      const response = await axios.get(url, {
        headers: getGHLHeaders(apiKey),
        params: params,
        timeout: 30000
      });
      
      if (response.status === 429) {
        console.log('⚠️ Rate limit hit, waiting 60 seconds...');
        await new Promise(resolve => setTimeout(resolve, 60000));
        continue; // Retry same page
      }
      
      const data = response.data;
      const opportunities = data.opportunities || [];
      
      if (opportunities.length === 0) {
        console.log(`   ✅ No more opportunities found (page ${page})`);
        break;
      }
      
      // Filter opportunities by:
      // 1. Created after timestamp
      // 2. Belongs to target pipelines
      const filtered = opportunities.filter(opp => {
        const createdAt = opp.createdAt;
        const pipelineId = opp.pipelineId;
        
        // Check if created after timestamp
        if (createdAt && createdAt >= sinceDate) {
          // Check if belongs to target pipelines
          return pipelineIds.includes(pipelineId);
        }
        return false;
      });
      
      allOpportunities.push(...filtered);
      console.log(`   📄 Page ${page}: Found ${filtered.length} new opportunities (Total: ${allOpportunities.length})`);
      
      // If we got fewer results than limit, this is likely the last page
      if (opportunities.length < limit) {
        console.log(`   ✅ Reached last page`);
        break;
      }
      
      page++;
      
      // Small delay to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      if (error.response?.status === 429) {
        console.log('⚠️ Rate limit hit, waiting 60 seconds...');
        await new Promise(resolve => setTimeout(resolve, 60000));
        continue; // Retry same page
      }
      
      console.error(`❌ Error fetching page ${page}:`, error.message);
      // Continue with what we have so far
      break;
    }
  }
  
  console.log(`✅ Total opportunities fetched: ${allOpportunities.length}`);
  return allOpportunities;
}

/**
 * Update sync timestamp and stats in Firebase
 */
async function updateSyncTimestamp(db, stats) {
  try {
    const now = new Date();
    await db.collection('syncMetadata').doc('ghlLeads').set({
      lastGHLLeadSync: admin.firestore.Timestamp.fromDate(now),
      lastSyncStatus: stats.errors > 0 ? 'error' : 'success',
      lastSyncStats: {
        totalFetched: stats.totalFetched,
        newLeadsCreated: stats.newLeadsCreated,
        duplicatesSkipped: stats.duplicatesSkipped,
        errors: stats.errors
      },
      lastSyncError: stats.lastError || null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    console.log(`✅ Sync metadata updated: ${now.toISOString()}`);
  } catch (error) {
    console.error('❌ Error updating sync timestamp:', error);
  }
}

/**
 * Main sync function
 * @param {string} apiKey - GHL API key (optional, will try to get from config if not provided)
 */
async function syncGHLLeads(apiKey = null) {
  const db = admin.firestore();
  
  // Get API key from parameter, config, or environment
  if (!apiKey) {
    try {
      const functions = require('firebase-functions');
      apiKey = functions.config().ghl?.api_key || process.env.GHL_API_KEY;
    } catch (e) {
      // If firebase-functions not available (e.g., in tests), use env var
      apiKey = process.env.GHL_API_KEY;
    }
  }
  
  if (!apiKey) {
    throw new Error('GHL_API_KEY not configured. Set it in Firebase config or environment variable.');
  }
  
  const startTime = Date.now();
  const stats = {
    totalFetched: 0,
    newLeadsCreated: 0,
    duplicatesSkipped: 0,
    errors: 0,
    lastError: null
  };
  
  try {
    console.log('='.repeat(80));
    console.log('🔄 GHL LEADS SYNC - Starting');
    console.log('='.repeat(80));
    console.log();
    
    // Get last sync timestamp
    const lastSyncTimestamp = await getLastSyncTimestamp(db);
    console.log(`📅 Last sync timestamp: ${lastSyncTimestamp.toISOString()}`);
    console.log();
    
    // Fetch opportunities since last sync
    const pipelineIds = [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID];
    const opportunities = await fetchOpportunitiesSinceTimestamp(
      lastSyncTimestamp,
      pipelineIds,
      apiKey
    );
    
    stats.totalFetched = opportunities.length;
    console.log();
    
    if (opportunities.length === 0) {
      console.log('✅ No new opportunities found');
      await updateSyncTimestamp(db, stats);
      return { success: true, stats };
    }
    
    console.log('='.repeat(80));
    console.log('💾 PROCESSING LEADS');
    console.log('='.repeat(80));
    console.log();
    
    // Process each opportunity
    for (let i = 0; i < opportunities.length; i++) {
      const opp = opportunities[i];
      
      try {
        const contactId = opp.contactId || opp.contact?.id;
        
        if (!contactId) {
          console.log(`⚠️ Skipped opportunity ${opp.id}: no contactId`);
          stats.errors++;
          continue;
        }
        
        // Check if lead already exists
        const exists = await checkLeadExists(db, contactId);
        
        if (exists) {
          stats.duplicatesSkipped++;
          if ((i + 1) % 50 === 0) {
            console.log(`   Processed ${i + 1}/${opportunities.length}... (${stats.newLeadsCreated} created, ${stats.duplicatesSkipped} skipped)`);
          }
          continue;
        }
        
        // Extract contact information
        const contact = opp.contact || {};
        if (!contact.name && !opp.name) {
          console.log(`⚠️ Skipped opportunity ${opp.id}: no contact name`);
          stats.errors++;
          continue;
        }
        
        // Extract lead data
        const leadData = extractLeadData(opp, contact);
        
        // Create lead in Firebase
        const created = await createLeadInFirebase(db, contactId, leadData);
        
        if (created) {
          stats.newLeadsCreated++;
          if (stats.newLeadsCreated % 10 === 0) {
            console.log(`   ✅ Created ${stats.newLeadsCreated} leads...`);
          }
        } else {
          stats.errors++;
        }
        
        // Progress update every 50 opportunities
        if ((i + 1) % 50 === 0) {
          console.log(`   Processed ${i + 1}/${opportunities.length}... (${stats.newLeadsCreated} created, ${stats.duplicatesSkipped} skipped)`);
        }
        
      } catch (error) {
        console.error(`❌ Error processing opportunity ${opp.id}:`, error.message);
        stats.errors++;
        stats.lastError = error.message;
      }
    }
    
    console.log();
    console.log('='.repeat(80));
    console.log('✅ SYNC COMPLETE');
    console.log('='.repeat(80));
    console.log(`   📊 Total fetched: ${stats.totalFetched}`);
    console.log(`   ➕ New leads created: ${stats.newLeadsCreated}`);
    console.log(`   ⏭️  Duplicates skipped: ${stats.duplicatesSkipped}`);
    console.log(`   ❌ Errors: ${stats.errors}`);
    console.log(`   ⏱️  Duration: ${((Date.now() - startTime) / 1000).toFixed(1)}s`);
    console.log('='.repeat(80));
    console.log();
    
    // Update sync timestamp
    await updateSyncTimestamp(db, stats);
    
    return { success: true, stats };
    
  } catch (error) {
    console.error('❌ Sync failed:', error);
    stats.lastError = error.message;
    await updateSyncTimestamp(db, stats);
    throw error;
  }
}

module.exports = {
  syncGHLLeads
};
