#!/usr/bin/env python3
"""
Fetch actual stage IDs from GHL API and update ghlOpportunities
"""

import firebase_admin
from firebase_admin import credentials, firestore
import requests
import os
import json

# Initialize Firebase
script_dir = os.path.dirname(os.path.abspath(__file__))
creds_path = os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
cred = credentials.Certificate(creds_path)

try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

# GHL API credentials
GHL_API_KEY = 'pit-22f8af95-3244-41e7-9a52-22c87b166f5a'
GHL_LOCATION_ID = 'QdLXaFEqrdF0JbVbpKLw'

# Load pipeline stage mappings
mappings_path = os.path.join(script_dir, '..', 'ghl_info', 'pipeline_stage_mappings.json')
with open(mappings_path, 'r') as f:
    stage_mappings = json.load(f)

# Build reverse lookup: stage_id -> stage_name
stage_id_to_name = {}
for pipeline_key, pipeline_data in stage_mappings.items():
    for stage_id, stage_name in pipeline_data['stages'].items():
        stage_id_to_name[stage_id] = {
            'name': stage_name,
            'pipeline': pipeline_key
        }

print("=" * 80)
print("FETCHING ACTUAL STAGE IDS FROM GHL API")
print("=" * 80)
print()

# Categorize stages
def get_stage_category_from_name(stage_name):
    """Determine category based on stage name"""
    stage_lower = stage_name.lower()
    
    if 'booked' in stage_lower or 'appointment' in stage_lower:
        return 'booking'
    elif 'deposit' in stage_lower:
        return 'deposit'
    elif 'cash' in stage_lower:
        return 'cash_collected'
    elif 'lost' in stage_lower or 'disqualified' in stage_lower or 'dnd' in stage_lower:
        return 'lost'
    else:
        return 'lead'

# Fetch opportunities from GHL API
print("📊 STEP 1: Fetching opportunities from GHL API...")
print()

headers = {
    'Authorization': f'Bearer {GHL_API_KEY}',
    'Version': '2021-07-28',
    'Content-Type': 'application/json'
}

all_opportunities = []
page = 1

while True:
    print(f"   Fetching page {page}...")
    
    params = {
        'location_id': GHL_LOCATION_ID,
        'limit': 100,
        'page': page
    }
    
    response = requests.get(
        'https://services.leadconnectorhq.com/opportunities/search',
        headers=headers,
        params=params,
        timeout=30
    )
    
    if response.status_code != 200:
        print(f"   ⚠️  Error: {response.status_code}")
        break
    
    data = response.json()
    opportunities = data.get('opportunities', [])
    
    if not opportunities:
        print(f"   ✅ Reached end of data")
        break
    
    all_opportunities.extend(opportunities)
    
    # Check if there are more pages
    if len(opportunities) < 100:
        break
    
    page += 1

print(f"✅ Fetched {len(all_opportunities)} opportunities")
print()

# Filter to Andries & Davide pipelines
ANDRIES_PIPELINE_ID = 'XeAGJWRnUGJ5tuhXam2g'
DAVIDE_PIPELINE_ID = 'AUduOJBB2lxlsEaNmlJz'

filtered_opportunities = [
    opp for opp in all_opportunities
    if opp.get('pipelineId') in [ANDRIES_PIPELINE_ID, DAVIDE_PIPELINE_ID]
]

print(f"✅ Filtered to {len(filtered_opportunities)} opportunities (Andries & Davide)")
print()

# Update ghlOpportunities with actual stage IDs
print("📊 STEP 2: Updating ghlOpportunities with actual stage IDs...")
print()

batch = db.batch()
batch_count = 0
updated_count = 0
stage_stats = {
    'lead': 0,
    'booking': 0,
    'deposit': 0,
    'cash_collected': 0,
    'lost': 0
}

for opp in filtered_opportunities:
    opp_id = opp.get('id')
    stage_id = opp.get('pipelineStageId')  # This is the actual stage UUID!
    status = opp.get('status', 'open')
    
    if not opp_id:
        continue
    
    # Look up stage name from mapping
    stage_info = stage_id_to_name.get(stage_id, {})
    stage_name = stage_info.get('name', 'Unknown')
    stage_category = get_stage_category_from_name(stage_name)
    
    # Update stats
    stage_stats[stage_category] += 1
    
    # Update Firestore (use set with merge=True to create or update)
    opp_ref = db.collection('ghlOpportunities').document(opp_id)
    
    # Use set with merge=True to update existing or create new documents
    batch.set(opp_ref, {
        'stageId': stage_id,
        'stageName': stage_name,
        'stageCategory': stage_category,
        'status': status,
        'currentStage': status,
        'opportunityId': opp_id,
        'pipelineId': opp.get('pipelineId'),
        'pipelineName': 'Andries Pipeline' if opp.get('pipelineId') == ANDRIES_PIPELINE_ID else 'Davide Pipeline',
        'lastUpdated': firestore.SERVER_TIMESTAMP
    }, merge=True)
    
    batch_count += 1
    updated_count += 1
    
    if batch_count >= 500:
        batch.commit()
        print(f"   ✅ Committed batch ({updated_count} opportunities updated)")
        batch = db.batch()
        batch_count = 0

# Commit remaining
if batch_count > 0:
    batch.commit()

print()
print(f"✅ Updated {updated_count} opportunities with actual stage IDs")
print()

# Print stage distribution
print("=" * 80)
print("📊 STAGE DISTRIBUTION:")
print("=" * 80)
print()
print(f"   Leads: {stage_stats['lead']}")
print(f"   Bookings: {stage_stats['booking']}")
print(f"   Deposits: {stage_stats['deposit']}")
print(f"   Cash Collected: {stage_stats['cash_collected']}")
print(f"   Lost: {stage_stats['lost']}")
print()
print("=" * 80)
print("✅ STAGE UPDATE COMPLETE!")
print("=" * 80)
print()

