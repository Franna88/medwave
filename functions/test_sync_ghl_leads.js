/**
 * Test script for GHL Leads Sync
 * Run this locally to test the sync function before deploying
 * 
 * Usage:
 *   node test_sync_ghl_leads.js
 * 
 * Make sure GHL_API_KEY is set in environment:
 *   export GHL_API_KEY='your-api-key'
 *   or
 *   set GHL_API_KEY=your-api-key (Windows)
 */

const admin = require('firebase-admin');
const { syncGHLLeads } = require('./lib/syncGHLLeads');

// Initialize Firebase Admin
try {
  const path = require('path');
  const fs = require('fs');
  
  // Service account file location (from ghl_opp_collection folder)
  const serviceAccountPath = path.join(__dirname, '..', 'ghl_opp_collection', 'medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json');
  
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'medx-ai'
    });
    console.log(`✅ Firebase initialized with service account: ${path.basename(serviceAccountPath)}`);
    console.log(`   Project ID: ${serviceAccount.project_id || 'medx-ai'}`);
  } else {
    console.error(`❌ Service account file not found at: ${serviceAccountPath}`);
    console.log('\n💡 Make sure the service account JSON file exists at:');
    console.log('   ghl_opp_collection/medx-ai-firebase-adminsdk-fbsvc-d88a6aa1a7.json');
    process.exit(1);
  }
} catch (error) {
  if (error.code === 'app/already-initialized') {
    console.log('✅ Firebase already initialized');
  } else {
    console.error('❌ Firebase initialization error:', error.message);
    console.error('   Stack:', error.stack);
    process.exit(1);
  }
}

// Check for API key
const apiKey = process.env.GHL_API_KEY;
if (!apiKey) {
  console.error('❌ GHL_API_KEY not found in environment variables');
  console.log('\n💡 Set it with:');
  console.log('   export GHL_API_KEY="your-api-key"');
  console.log('   or');
  console.log('   set GHL_API_KEY=your-api-key (Windows)');
  process.exit(1);
}

// Run the sync
async function testSync() {
  const db = admin.firestore();
  
  console.log('='.repeat(80));
  console.log('🧪 TESTING GHL LEADS SYNC');
  console.log('='.repeat(80));
  console.log();
  
  // Check if syncMetadata exists
  console.log('📋 Checking sync metadata...');
  const syncDoc = await db.collection('syncMetadata').doc('ghlLeads').get();
  
  if (syncDoc.exists) {
    const data = syncDoc.data();
    console.log('   ✅ Sync metadata found');
    console.log('   Last sync:', data.lastGHLLeadSync?.toDate?.() || data.lastGHLLeadSync || 'Never');
    console.log('   Status:', data.lastSyncStatus || 'Unknown');
  } else {
    console.log('   ⚠️  No sync metadata found - will use baseline (Dec 11, 2025)');
  }
  console.log();
  
  // Run the sync
  console.log('🔄 Starting sync...');
  console.log();
  
  try {
    const startTime = Date.now();
    const result = await syncGHLLeads(apiKey);
    const duration = ((Date.now() - startTime) / 1000).toFixed(1);
    
    console.log();
    console.log('='.repeat(80));
    console.log('✅ TEST COMPLETE');
    console.log('='.repeat(80));
    console.log();
    console.log('📊 Results:');
    console.log('   Success:', result.success);
    console.log('   Total fetched:', result.stats.totalFetched);
    console.log('   New leads created:', result.stats.newLeadsCreated);
    console.log('   Duplicates skipped:', result.stats.duplicatesSkipped);
    console.log('   Errors:', result.stats.errors);
    console.log('   Duration:', duration + 's');
    console.log();
    
    // Check updated sync metadata
    const updatedSyncDoc = await db.collection('syncMetadata').doc('ghlLeads').get();
    if (updatedSyncDoc.exists) {
      const updatedData = updatedSyncDoc.data();
      console.log('📅 Updated sync metadata:');
      console.log('   Last sync:', updatedData.lastGHLLeadSync?.toDate?.() || updatedData.lastGHLLeadSync);
      console.log('   Status:', updatedData.lastSyncStatus);
      console.log('   Stats:', JSON.stringify(updatedData.lastSyncStats, null, 2));
    }
    
    console.log();
    console.log('='.repeat(80));
    console.log('✅ All tests passed! Ready to deploy.');
    console.log('='.repeat(80));
    
    process.exit(0);
  } catch (error) {
    console.error();
    console.error('='.repeat(80));
    console.error('❌ TEST FAILED');
    console.error('='.repeat(80));
    console.error('Error:', error.message);
    console.error('Stack:', error.stack);
    console.error();
    
    // Check if sync metadata was updated despite error
    const errorSyncDoc = await db.collection('syncMetadata').doc('ghlLeads').get();
    if (errorSyncDoc.exists) {
      const errorData = errorSyncDoc.data();
      console.log('📊 Sync metadata after error:');
      console.log('   Status:', errorData.lastSyncStatus);
      console.log('   Error:', errorData.lastSyncError);
    }
    
    process.exit(1);
  }
}

testSync();
