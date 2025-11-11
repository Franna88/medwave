/**
 * Opportunity Mapping Service
 * 
 * Assigns ONE ad to each GHL opportunity to prevent cross-campaign duplicates.
 * Uses a 3-tier priority system for assignment.
 */

const admin = require('firebase-admin');

/**
 * Calculate string similarity (Levenshtein distance based)
 * @param {string} str1 - First string
 * @param {string} str2 - Second string
 * @returns {number} Similarity score (0-1, higher is more similar)
 */
function stringSimilarity(str1, str2) {
  if (!str1 || !str2) return 0;
  
  const s1 = str1.toLowerCase().trim();
  const s2 = str2.toLowerCase().trim();
  
  if (s1 === s2) return 1;
  
  // Simple similarity: count matching characters
  const longer = s1.length > s2.length ? s1 : s2;
  const shorter = s1.length > s2.length ? s2 : s1;
  
  if (longer.length === 0) return 1;
  
  let matches = 0;
  for (let i = 0; i < shorter.length; i++) {
    if (longer.includes(shorter[i])) {
      matches++;
    }
  }
  
  return matches / longer.length;
}

/**
 * Assign an Ad ID to an opportunity using priority matching
 * @param {Object} opportunityData - The opportunity data from GHL
 * @returns {Promise<Object>} Assignment result with adId and metadata
 */
async function assignAdIdToOpportunity(opportunityData) {
  const db = admin.firestore();
  const opportunityId = opportunityData.id || opportunityData.opportunityId;
  
  if (!opportunityId) {
    throw new Error('Opportunity ID is required');
  }
  
  try {
    // Check if mapping already exists
    const existingMapping = await db.collection('ghlOpportunityMapping')
      .doc(opportunityId)
      .get();
    
    if (existingMapping.exists) {
      console.log(`✅ Opportunity ${opportunityId} already mapped to ${existingMapping.data().assignedAdId}`);
      return existingMapping.data();
    }
    
    // Extract attribution data
    const attributions = opportunityData.attributions || [];
    let assignedAdId = null;
    let assignmentMethod = null;
    let confidence = 0;
    let matchedAd = null;
    
    // ========================================================================
    // PRIORITY 1: Direct h_ad_id match (100% confidence)
    // ========================================================================
    
    for (let i = attributions.length - 1; i >= 0; i--) {
      const attr = attributions[i];
      const h_ad_id = attr.h_ad_id || attr.utmAdId || attr.adId;
      
      if (h_ad_id) {
        // Check if this ad exists
        const adDoc = await db.collection('ads').doc(h_ad_id).get();
        
        if (adDoc.exists) {
          assignedAdId = h_ad_id;
          assignmentMethod = 'h_ad_id';
          confidence = 100;
          matchedAd = adDoc.data();
          console.log(`✅ Priority 1: Matched opportunity ${opportunityId} to ad ${h_ad_id} via h_ad_id`);
          break;
        }
      }
    }
    
    // ========================================================================
    // PRIORITY 2: Campaign ID + Ad Name match (80% confidence)
    // ========================================================================
    
    if (!assignedAdId) {
      for (let i = attributions.length - 1; i >= 0; i--) {
        const attr = attributions[i];
        const campaignId = attr.utmCampaignId || attr.campaignId;
        const adName = (attr.utmCampaign || attr.adName || '').toLowerCase().trim();
        
        if (campaignId && adName) {
          // Find ads in this campaign
          const adsSnapshot = await db.collection('ads')
            .where('campaignId', '==', campaignId)
            .get();
          
          if (!adsSnapshot.empty) {
            // Try exact match first
            let bestMatch = null;
            let bestSimilarity = 0;
            
            adsSnapshot.forEach(adDoc => {
              const ad = adDoc.data();
              const adNameLower = (ad.adName || '').toLowerCase().trim();
              
              // Exact match
              if (adNameLower === adName) {
                bestMatch = { id: adDoc.id, ad: ad };
                bestSimilarity = 1;
              } 
              // Fuzzy match (if no exact match yet)
              else if (bestSimilarity < 1) {
                const similarity = stringSimilarity(adName, adNameLower);
                if (similarity > bestSimilarity && similarity > 0.7) {
                  bestMatch = { id: adDoc.id, ad: ad };
                  bestSimilarity = similarity;
                }
              }
            });
            
            if (bestMatch) {
              assignedAdId = bestMatch.id;
              assignmentMethod = 'campaign_id_and_ad_name';
              confidence = Math.round(bestSimilarity * 80); // 80% max for this method
              matchedAd = bestMatch.ad;
              console.log(`✅ Priority 2: Matched opportunity ${opportunityId} to ad ${assignedAdId} via campaign+name (${confidence}% confidence)`);
              break;
            }
          }
        }
      }
    }
    
    // ========================================================================
    // PRIORITY 3: Campaign ID only (60% confidence)
    // ========================================================================
    
    if (!assignedAdId) {
      for (let i = attributions.length - 1; i >= 0; i--) {
        const attr = attributions[i];
        const campaignId = attr.utmCampaignId || attr.campaignId;
        
        if (campaignId) {
          // Find first ad in this campaign
          const adsSnapshot = await db.collection('ads')
            .where('campaignId', '==', campaignId)
            .limit(1)
            .get();
          
          if (!adsSnapshot.empty) {
            const adDoc = adsSnapshot.docs[0];
            assignedAdId = adDoc.id;
            assignmentMethod = 'campaign_id';
            confidence = 60;
            matchedAd = adDoc.data();
            console.log(`✅ Priority 3: Matched opportunity ${opportunityId} to ad ${assignedAdId} via campaign_id only`);
            break;
          }
        }
      }
    }
    
    // ========================================================================
    // No match found
    // ========================================================================
    
    if (!assignedAdId) {
      console.log(`⚠️  Could not assign ad to opportunity ${opportunityId} - no matching criteria found`);
      return {
        success: false,
        opportunityId: opportunityId,
        message: 'No matching ad found'
      };
    }
    
    // ========================================================================
    // Create mapping document
    // ========================================================================
    
    const mappingDoc = {
      opportunityId: opportunityId,
      assignedAdId: assignedAdId,
      assignmentMethod: assignmentMethod,
      assignmentConfidence: confidence,
      campaignId: matchedAd.campaignId || '',
      campaignName: matchedAd.campaignName || '',
      adName: matchedAd.adName || '',
      adSetId: matchedAd.adSetId || '',
      adSetName: matchedAd.adSetName || '',
      stage: opportunityData.status || '',
      stageCategory: getStageCategory(opportunityData.status || ''),
      monetaryValue: opportunityData.monetaryValue || 0,
      opportunityCreatedAt: opportunityData.createdAt || opportunityData.dateAdded || null,
      assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastVerified: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Save mapping
    await db.collection('ghlOpportunityMapping').doc(opportunityId).set(mappingDoc, { merge: true });
    
    console.log(`✅ Created mapping for opportunity ${opportunityId} -> ad ${assignedAdId} (${assignmentMethod}, ${confidence}%)`);
    
    return {
      success: true,
      ...mappingDoc
    };
    
  } catch (error) {
    console.error(`Error assigning ad to opportunity ${opportunityId}:`, error);
    throw error;
  }
}

/**
 * Get stage category from stage name
 * @param {string} stageName - The stage name
 * @returns {string} Stage category
 */
function getStageCategory(stageName) {
  if (!stageName) return 'other';
  
  const stageLower = stageName.toLowerCase();
  
  if (stageLower.includes('appointment') || stageLower.includes('booked') || stageLower.includes('scheduled')) {
    return 'bookedAppointments';
  } else if (stageLower.includes('deposit') || stageLower.includes('paid deposit')) {
    return 'deposits';
  } else if (stageLower.includes('cash collected') || stageLower.includes('paid') || 
             stageLower.includes('completed') || stageLower.includes('payment received')) {
    return 'cashCollected';
  } else {
    return 'other';
  }
}

/**
 * Get assigned ad ID for an opportunity (from mapping)
 * @param {string} opportunityId - The opportunity ID
 * @returns {Promise<string|null>} Assigned ad ID or null
 */
async function getAssignedAdId(opportunityId) {
  const db = admin.firestore();
  
  try {
    const mappingDoc = await db.collection('ghlOpportunityMapping')
      .doc(opportunityId)
      .get();
    
    if (mappingDoc.exists) {
      return mappingDoc.data().assignedAdId;
    }
    
    return null;
    
  } catch (error) {
    console.error(`Error getting assigned ad for opportunity ${opportunityId}:`, error);
    return null;
  }
}

/**
 * Verify mapping integrity (check for duplicates)
 * @returns {Promise<Object>} Verification results
 */
async function verifyMappingIntegrity() {
  const db = admin.firestore();
  
  try {
    console.log('🔍 Verifying opportunity mapping integrity...');
    
    // Get all opportunities
    const opportunitiesSnapshot = await db.collection('ghlOpportunities').get();
    
    // Track which opportunities appear in which campaigns
    const opportunityToCampaigns = {};
    
    opportunitiesSnapshot.forEach(oppDoc => {
      const opp = oppDoc.data();
      const oppId = oppDoc.id;
      const campaignId = opp.campaignId;
      
      if (!opportunityToCampaigns[oppId]) {
        opportunityToCampaigns[oppId] = new Set();
      }
      opportunityToCampaigns[oppId].add(campaignId);
    });
    
    // Find duplicates
    const duplicates = [];
    
    for (const [oppId, campaigns] of Object.entries(opportunityToCampaigns)) {
      if (campaigns.size > 1) {
        duplicates.push({
          opportunityId: oppId,
          campaignCount: campaigns.size,
          campaigns: Array.from(campaigns)
        });
      }
    }
    
    if (duplicates.length > 0) {
      console.log(`❌ Found ${duplicates.length} opportunities in multiple campaigns!`);
      return {
        success: false,
        duplicates: duplicates,
        totalOpportunities: opportunitiesSnapshot.size
      };
    } else {
      console.log(`✅ No duplicates found! All ${opportunitiesSnapshot.size} opportunities in single campaigns.`);
      return {
        success: true,
        duplicates: [],
        totalOpportunities: opportunitiesSnapshot.size
      };
    }
    
  } catch (error) {
    console.error('Error verifying mapping integrity:', error);
    throw error;
  }
}

module.exports = {
  assignAdIdToOpportunity,
  getAssignedAdId,
  getStageCategory,
  verifyMappingIntegrity,
  stringSimilarity
};

