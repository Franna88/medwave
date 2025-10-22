#!/usr/bin/env node

/**
 * Debug Script: Find Unknown Campaign Leads in GoHighLevel
 * 
 * This script queries GoHighLevel API to identify opportunities 
 * that don't have UTM tracking (the "Unknown Campaign" leads)
 */

const https = require('https');

// GoHighLevel Configuration
const GHL_API_KEY = process.env.GHL_API_KEY || 'YOUR_API_KEY_HERE';
const LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'; // MedWave SA
const ALTUS_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz';
const ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g';

/**
 * Make HTTPS request to GoHighLevel API
 */
function makeRequest(path) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'services.leadconnectorhq.com',
      path: path,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${GHL_API_KEY}`,
        'Version': '2021-07-28',
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    });

    req.on('error', reject);
    req.end();
  });
}

/**
 * Fetch opportunities from a pipeline
 */
async function fetchOpportunities(pipelineId, pipelineName) {
  console.log(`\n📊 Fetching opportunities from ${pipelineName} Pipeline...`);
  
  const path = `/opportunities/search?location_id=${LOCATION_ID}&pipeline_id=${pipelineId}&limit=100`;
  const response = await makeRequest(path);
  
  console.log('API Response:', JSON.stringify(response, null, 2).substring(0, 500));
  
  return response.opportunities || [];
}

/**
 * Check if opportunity has tracking data
 */
function hasTrackingData(opp) {
  if (!opp.attributions || opp.attributions.length === 0) {
    return false;
  }
  
  const lastAttr = opp.attributions.find(a => a.isLast) || opp.attributions[0];
  return !!(lastAttr?.utmCampaign || lastAttr?.utmSource || lastAttr?.utmMedium);
}

/**
 * Main function
 */
async function main() {
  console.log('🔍 GoHighLevel Unknown Campaign Debugger\n');
  console.log('=' .repeat(60));
  
  if (GHL_API_KEY === 'YOUR_API_KEY_HERE') {
    console.error('\n❌ ERROR: Please set GHL_API_KEY environment variable');
    console.log('\nUsage:');
    console.log('  export GHL_API_KEY="your-api-key-here"');
    console.log('  node debug_unknown_campaigns.js');
    process.exit(1);
  }

  try {
    // Fetch from both pipelines
    const altusOpps = await fetchOpportunities(ALTUS_PIPELINE_ID, 'Altus');
    const andriesOpps = await fetchOpportunities(ANDRIES_PIPELINE_ID, 'Andries');
    
    const allOpps = [...altusOpps, ...andriesOpps];
    console.log(`\n✅ Total opportunities fetched: ${allOpps.length}`);
    
    // Filter for unknown campaigns (no tracking)
    const unknownOpps = allOpps.filter(opp => !hasTrackingData(opp));
    
    console.log(`\n🔍 Found ${unknownOpps.length} opportunities WITHOUT tracking data:\n`);
    console.log('=' .repeat(60));
    
    // Display details for each unknown opportunity
    unknownOpps.forEach((opp, index) => {
      console.log(`\n📋 Lead #${index + 1}:`);
      console.log(`   ID: ${opp.id}`);
      console.log(`   Name: ${opp.name || 'N/A'}`);
      console.log(`   Contact: ${opp.contact?.name || 'N/A'}`);
      console.log(`   Email: ${opp.contact?.email || 'N/A'}`);
      console.log(`   Phone: ${opp.contact?.phone || 'N/A'}`);
      console.log(`   Stage: ${opp.pipelineStageName || 'N/A'}`);
      console.log(`   Created: ${opp.createdAt ? new Date(opp.createdAt).toLocaleString() : 'N/A'}`);
      console.log(`   Source: ${opp.source || 'NONE'}`);
      console.log(`   Lead Source: ${opp.leadSource || 'NONE'}`);
      console.log(`   Lead Value: ${opp.leadValue || 'NONE'}`);
      console.log(`   Assigned To: ${opp.assignedToName || opp.assignedTo || 'Unassigned'}`);
      console.log(`   Has Attributions: ${opp.attributions ? 'Yes (' + opp.attributions.length + ')' : 'No'}`);
      
      if (opp.tags && opp.tags.length > 0) {
        console.log(`   Tags: ${opp.tags.join(', ')}`);
      }
      
      if (opp.customFields && Object.keys(opp.customFields).length > 0) {
        console.log(`   Custom Fields: ${JSON.stringify(opp.customFields, null, 2)}`);
      }
    });
    
    // Summary
    console.log('\n' + '=' .repeat(60));
    console.log('\n📊 SUMMARY:');
    console.log(`   Total Opportunities: ${allOpps.length}`);
    console.log(`   With Tracking: ${allOpps.length - unknownOpps.length}`);
    console.log(`   Without Tracking (Unknown Campaign): ${unknownOpps.length}`);
    console.log(`   Percentage Unknown: ${((unknownOpps.length / allOpps.length) * 100).toFixed(1)}%`);
    
    // Group by source
    const bySources = {};
    unknownOpps.forEach(opp => {
      const source = opp.source || opp.leadSource || 'NO SOURCE';
      bySources[source] = (bySources[source] || 0) + 1;
    });
    
    console.log('\n📈 Unknown Leads by Source:');
    Object.entries(bySources).forEach(([source, count]) => {
      console.log(`   ${source}: ${count}`);
    });
    
  } catch (error) {
    console.error('\n❌ ERROR:', error.message);
    if (error.response) {
      console.error('Response:', error.response);
    }
  }
}

// Run the script
main();

