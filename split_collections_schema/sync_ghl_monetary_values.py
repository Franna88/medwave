#!/usr/bin/env python3
"""
Sync GHL Opportunity Monetary Values to Firebase
Fetches all opportunities from GHL API and updates ghlOpportunities with:
- monetaryValue
- stageId
- stageName
- stageCategory
- All other opportunity fields
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
import json
import time
from datetime import datetime

# Initialize Firebase
script_dir = os.path.dirname(os.path.abspath(__file__))
creds_path = os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
cred = credentials.Certificate(creds_path)

try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

# GHL API credentials (from ADVERTDATA_IMPLEMENTATION_SESSION_SUMMARY.md)
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'  # CORRECTED Nov 10, 2025

# Load pipeline stage mappings
mappings_path = os.path.join(script_dir, '..', 'ghl_info', 'pipeline_stage_mappings.json')
with open(mappings_path, 'r') as f:
    stage_mappings = json.load(f)

# Build reverse lookup: stage_id -> stage_info
stage_id_to_info = {}
for pipeline_key, pipeline_data in stage_mappings.items():
    for stage_id, stage_name in pipeline_data['stages'].items():
        stage_id_to_info[stage_id] = {
            'name': stage_name,
            'pipeline': pipeline_key
        }

def get_stage_category_from_name(stage_name):
    """Determine category based on stage name"""
    stage_lower = stage_name.lower()
    
    if 'booked' in stage_lower or 'appointment' in stage_lower:
        return 'booking'
    elif 'deposit' in stage_lower:
        return 'deposit'
    elif 'cash' in stage_lower or 'collected' in stage_lower:
        return 'cash_collected'
    elif 'lost' in stage_lower or 'disqualified' in stage_lower or 'dnd' in stage_lower:
        return 'lost'
    else:
        return 'lead'

print("=" * 80)
print("SYNCING GHL MONETARY VALUES TO FIREBASE")
print("=" * 80)
print()
print("This script will:")
print("  1. Fetch ALL opportunities from GHL API (with pagination)")
print("  2. Extract monetaryValue, stageId, stageName, and other fields")
print("  3. Update ghlOpportunities in Firebase with complete data")
print("  4. Use retry logic to handle timeouts")
print()
print("=" * 80)
print()

# ============================================================================
# STEP 1: Fetch existing opportunities from Firebase to get their IDs
# ============================================================================
print("📊 STEP 1: Loading existing opportunities from Firebase...")
print()

firebase_opps = {}
opps_ref = db.collection('ghlOpportunities').stream()
for opp_doc in opps_ref:
    opp_data = opp_doc.to_dict()
    firebase_opps[opp_doc.id] = opp_data

print(f"✅ Found {len(firebase_opps)} opportunities in Firebase")
print()

# ============================================================================
# STEP 2: Fetch ALL opportunities from GHL API with retry logic
# ============================================================================
print("📊 STEP 2: Fetching opportunities from GHL API...")
print()

headers = {
    'Authorization': f'Bearer {GHL_API_KEY}',
    'Version': '2021-07-28',
    'Content-Type': 'application/json'
}

all_opportunities = []
page = 1
max_retries = 3

while True:
    print(f"   Fetching page {page}...")
    
    params = {
        'location_id': GHL_LOCATION_ID,
        'limit': 100,
        'page': page
    }
    
    retry_count = 0
    success = False
    should_continue = True
    
    while retry_count < max_retries and not success:
        try:
            response = requests.get(
                'https://services.leadconnectorhq.com/opportunities/search',
                headers=headers,
                params=params,
                timeout=60  # Increased timeout
            )
            
            if response.status_code != 200:
                print(f"   ⚠️  Error: {response.status_code}")
                if retry_count < max_retries - 1:
                    print(f"   🔄 Retrying... ({retry_count + 1}/{max_retries})")
                    time.sleep(2)
                    retry_count += 1
                    continue
                else:
                    should_continue = False
                    break
            
            data = response.json()
            opportunities = data.get('opportunities', [])
            
            if not opportunities or len(opportunities) == 0:
                print(f"   ✅ Reached end of data")
                success = True
                should_continue = False  # Stop the outer loop
                break
            
            all_opportunities.extend(opportunities)
            success = True
            page += 1  # Only increment if we got data
            
            # Small delay to avoid rate limits
            time.sleep(0.5)
            
        except requests.exceptions.Timeout:
            print(f"   ⚠️  Timeout on page {page}")
            if retry_count < max_retries - 1:
                print(f"   🔄 Retrying... ({retry_count + 1}/{max_retries})")
                time.sleep(5)
                retry_count += 1
            else:
                print(f"   ❌ Max retries reached, skipping to next page")
                page += 1
                success = True  # Mark as success to continue with next page
                break
        except Exception as e:
            print(f"   ❌ Error: {str(e)}")
            if retry_count < max_retries - 1:
                print(f"   🔄 Retrying... ({retry_count + 1}/{max_retries})")
                time.sleep(5)
                retry_count += 1
            else:
                should_continue = False
                break
    
    # Exit outer loop if we should stop
    if not should_continue:
        break

print()
print(f"✅ Fetched {len(all_opportunities)} total opportunities from GHL API")
print()

# Filter to Andries & Davide pipelines
filtered_opportunities = [
    opp for opp in all_opportunities
    if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]
]

print(f"✅ Filtered to {len(filtered_opportunities)} opportunities (Andries & Davide pipelines)")
print()

# ============================================================================
# STEP 3: Update Firebase with complete opportunity data
# ============================================================================
print("📊 STEP 3: Updating Firebase with GHL data...")
print()

batch = db.batch()
batch_count = 0
updated_count = 0
new_count = 0
with_monetary_value = 0
total_monetary_value = 0

stage_stats = {
    'lead': 0,
    'booking': 0,
    'deposit': 0,
    'cash_collected': 0,
    'lost': 0,
    'other': 0
}

for opp in filtered_opportunities:
    opp_id = opp.get('id')
    if not opp_id:
        continue
    
    # Extract all relevant fields
    stage_id = opp.get('pipelineStageId')
    status = opp.get('status', 'open')
    monetary_value = opp.get('monetaryValue', 0)
    
    # Look up stage name from mapping
    stage_info = stage_id_to_info.get(stage_id, {})
    stage_name = stage_info.get('name', 'Unknown')
    stage_category = get_stage_category_from_name(stage_name)
    
    # Determine pipeline name
    pipeline_id = opp.get('pipelineId')
    if pipeline_id == ANDRIES_PIPELINE_ID:
        pipeline_name = 'Andries Pipeline'
    elif pipeline_id == DAVIDE_PIPELINE_ID:
        pipeline_name = 'Davide Pipeline'
    else:
        pipeline_name = 'Unknown Pipeline'
    
    # Track stats
    stage_stats[stage_category] += 1
    if monetary_value > 0:
        with_monetary_value += 1
        total_monetary_value += monetary_value
    
    # Check if this is a new opportunity or update
    is_new = opp_id not in firebase_opps
    if is_new:
        new_count += 1
    
    # Prepare update data
    update_data = {
        'opportunityId': opp_id,
        'stageId': stage_id,
        'stageName': stage_name,
        'stageCategory': stage_category,
        'status': status,
        'currentStage': status,
        'pipelineId': pipeline_id,
        'pipelineName': pipeline_name,
        'monetaryValue': monetary_value,
        'name': opp.get('name', 'Unknown'),
        'contact': {
            'id': opp.get('contact', {}).get('id'),
            'name': opp.get('contact', {}).get('name'),
            'email': opp.get('contact', {}).get('email'),
            'phone': opp.get('contact', {}).get('phone')
        } if opp.get('contact') else None,
        'lastUpdated': firestore.SERVER_TIMESTAMP,
        'lastGHLSync': firestore.SERVER_TIMESTAMP
    }
    
    # Add created date if available
    if opp.get('createdAt'):
        update_data['createdAt'] = opp.get('createdAt')
    elif opp.get('dateAdded'):
        update_data['createdAt'] = opp.get('dateAdded')
    
    # Update Firestore (use set with merge=True to create or update)
    opp_ref = db.collection('ghlOpportunities').document(opp_id)
    batch.set(opp_ref, update_data, merge=True)
    
    batch_count += 1
    updated_count += 1
    
    # Commit batch every 500 documents
    if batch_count >= 500:
        batch.commit()
        print(f"   ✅ Committed batch ({updated_count} opportunities processed)")
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()

print()
print(f"✅ Updated {updated_count} opportunities in Firebase")
print(f"   - New opportunities: {new_count}")
print(f"   - Updated opportunities: {updated_count - new_count}")
print(f"   - With monetary value: {with_monetary_value} ({with_monetary_value / updated_count * 100:.1f}%)")
print(f"   - Total monetary value: R{total_monetary_value:,.0f}")
print()

# ============================================================================
# STEP 4: Display summary statistics
# ============================================================================
print("=" * 80)
print("📊 SUMMARY STATISTICS")
print("=" * 80)
print()
print(f"GHL API Fetch:")
print(f"  - Total opportunities fetched: {len(all_opportunities)}")
print(f"  - Andries & Davide pipelines: {len(filtered_opportunities)}")
print()
print(f"Firebase Update:")
print(f"  - Opportunities updated: {updated_count}")
print(f"  - New opportunities added: {new_count}")
print(f"  - With monetary value: {with_monetary_value} ({with_monetary_value / updated_count * 100:.1f}%)")
print(f"  - Total monetary value: R{total_monetary_value:,.0f}")
print()
print(f"Stage Distribution:")
print(f"  - Leads: {stage_stats['lead']}")
print(f"  - Bookings: {stage_stats['booking']}")
print(f"  - Deposits: {stage_stats['deposit']}")
print(f"  - Cash Collected: {stage_stats['cash_collected']}")
print(f"  - Lost: {stage_stats['lost']}")
print(f"  - Other: {stage_stats['other']}")
print()
print("=" * 80)
print("✅ SYNC COMPLETE!")
print("=" * 80)
print()
print("Next steps:")
print("  1. Run complete_ghl_reset_and_reaggregate.py to update ads with new monetary values")
print("  2. Verify monetary values in Firebase Console")
print("  3. Check that deposits and cash_collected now show correct amounts")
print()

