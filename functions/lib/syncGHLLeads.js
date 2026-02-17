/**
 * GHL Leads Sync Module
 * Fetches new leads from GoHighLevel (Andries, Davide, Elmien, and Karin pipelines)
 * and stores them in Firebase leads collection with deduplication
 */

const admin = require('firebase-admin');
const axios = require('axios');

// GHL API Configuration
const GHL_BASE_URL = 'https://services.leadconnectorhq.com';
const GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw';
const GHL_API_VERSION = '2021-07-28';

// Pipeline IDs
const ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g';
const DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz';
const ELMIEN_PIPELINE_ID = 'FSop78ljd2tK3C4KRQAA';
const KARIN_PIPELINE_ID = 'MIC1e4ef5NmSmfZEtePc';

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
 * Get existing lead IDs in batch using Firestore getAll()
 * Returns a Set of existing contact IDs for O(1) lookup
 */
async function getExistingLeadIds(db, contactIds) {
  const existingIds = new Set();
  
  // Firestore getAll() supports up to 500 document references per call
  const batchSize = 500;
  
  for (let i = 0; i < contactIds.length; i += batchSize) {
    const batch = contactIds.slice(i, i + batchSize);
    const docRefs = batch.map(contactId => db.collection('leads').doc(contactId));
    
    try {
      const docs = await db.getAll(...docRefs);
      docs.forEach(doc => {
        if (doc.exists) {
          existingIds.add(doc.id);
        }
      });
    } catch (error) {
      console.error(`⚠️ Error batch checking leads (batch ${Math.floor(i / batchSize) + 1}):`, error);
      // Continue with other batches even if one fails
    }
  }
  
  return existingIds;
}

/**
 * Batch create leads in Firebase
 * Processes leads in batches of 500 (Firestore batch limit)
 * Returns count of successfully created leads
 */
async function batchCreateLeads(db, leadsArray) {
  if (leadsArray.length === 0) {
    return 0;
  }
  
  const batchSize = 500;
  let createdCount = 0;
  
  for (let i = 0; i < leadsArray.length; i += batchSize) {
    const batch = leadsArray.slice(i, i + batchSize);
    const firestoreBatch = db.batch();
    
    batch.forEach(({ contactId, leadData }) => {
      const docRef = db.collection('leads').doc(contactId);
      firestoreBatch.set(docRef, leadData);
    });
    
    try {
      await firestoreBatch.commit();
      createdCount += batch.length;
      console.log(`   ✅ Committed batch ${Math.floor(i / batchSize) + 1}: ${createdCount} leads created so far...`);
    } catch (error) {
      console.error(`❌ Error committing batch ${Math.floor(i / batchSize) + 1}:`, error);
      // Continue with next batch even if one fails
    }
  }
  
  return createdCount;
}

/**
 * Fetch opportunities from GHL API since a given timestamp
 * Handles pagination and rate limiting with early termination
 * Stops fetching when encountering opportunities older than timestamp
 */
async function fetchOpportunitiesSinceTimestamp(timestamp, pipelineIds, apiKey) {
  const allOpportunities = [];
  const url = `${GHL_BASE_URL}/opportunities/search`;
  let page = 1;
  const limit = 100;
  const maxPages = 1000; // Safety limit
  
  // Convert timestamp to Date object for comparison (API returns ISO strings)
  const sinceDate = timestamp instanceof Date ? timestamp : new Date(timestamp);
  const sinceDateISO = sinceDate.toISOString();
  
  console.log(`📊 Fetching opportunities created after: ${sinceDateISO}`);
  
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
      
      // Filter opportunities by date range AND pipeline during fetch
      // Also check for early termination
      const filtered = [];
      let oldestOnPage = null;
      let shouldStop = false;
      
      for (const opp of opportunities) {
        const createdAt = opp.createdAt;
        const pipelineId = opp.pipelineId;
        
        if (!createdAt) {
          continue;
        }
        
        // Parse createdAt for comparison
        const createdAtDate = new Date(createdAt);
        
        // Track oldest opportunity on this page
        if (oldestOnPage === null || createdAtDate < oldestOnPage) {
          oldestOnPage = createdAtDate;
        }
        
        // Stop fetching if we've gone past our timestamp
        if (createdAtDate < sinceDate) {
          console.log(`   ⏹️  Reached opportunities older than ${sinceDateISO}, stopping fetch`);
          shouldStop = true;
          break;
        }
        
        // Check if created after timestamp AND belongs to target pipelines
        if (createdAt >= sinceDateISO && pipelineIds.includes(pipelineId)) {
          filtered.push(opp);
        }
      }
      
      allOpportunities.push(...filtered);
      console.log(`   📄 Page ${page}: Found ${filtered.length} new opportunities (Total: ${allOpportunities.length})`);
      
      // Stop if we encountered opportunities older than timestamp
      if (shouldStop || (oldestOnPage && oldestOnPage < sinceDate)) {
        console.log(`   ⏹️  Oldest opportunity on page (${oldestOnPage.toISOString()}) is before ${sinceDateISO}, stopping fetch`);
        break;
      }
      
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
    const pipelineIds = [
      ANDRIES_PIPELINE_ID,
      DAVIDE_PIPELINE_ID,
      ELMIEN_PIPELINE_ID,
      KARIN_PIPELINE_ID
    ];
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
    
    // Extract all contact IDs for batch existence check
    const contactIds = [];
    const opportunityMap = new Map(); // Map contactId -> opportunity
    
    for (const opp of opportunities) {
      const contactId = opp.contactId || opp.contact?.id;
      if (contactId) {
        contactIds.push(contactId);
        opportunityMap.set(contactId, opp);
      }
    }
    
    console.log(`📋 Checking existence of ${contactIds.length} leads...`);
    
    // Batch check which leads already exist
    const existingLeadIds = await getExistingLeadIds(db, contactIds);
    stats.duplicatesSkipped = existingLeadIds.size;
    
    console.log(`   Found ${existingLeadIds.size} existing leads, ${contactIds.length - existingLeadIds.size} new leads to create`);
    console.log();
    
    // Collect leads to create
    const leadsToCreate = [];
    
    for (const contactId of contactIds) {
      // Skip if already exists
      if (existingLeadIds.has(contactId)) {
        continue;
      }
      
      const opp = opportunityMap.get(contactId);
      
      try {
        // Extract contact information
        const contact = opp.contact || {};
        if (!contact.name && !opp.name) {
          console.log(`⚠️ Skipped opportunity ${opp.id}: no contact name`);
          stats.errors++;
          continue;
        }
        
        // Extract lead data
        const leadData = extractLeadData(opp, contact);
        
        leadsToCreate.push({
          contactId: contactId,
          leadData: leadData
        });
        
      } catch (error) {
        console.error(`❌ Error processing opportunity ${opp.id}:`, error.message);
        stats.errors++;
        stats.lastError = error.message;
      }
    }
    
    console.log(`📦 Prepared ${leadsToCreate.length} leads for batch creation`);
    console.log();
    
    // Batch create leads
    if (leadsToCreate.length > 0) {
      console.log('💾 Batch writing leads to Firestore...');
      const createdCount = await batchCreateLeads(db, leadsToCreate);
      stats.newLeadsCreated = createdCount;
      
      if (createdCount < leadsToCreate.length) {
        stats.errors += (leadsToCreate.length - createdCount);
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
