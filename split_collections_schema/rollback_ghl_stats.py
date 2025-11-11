#!/usr/bin/env python3
"""
Rollback GHL stats in ads collection by restoring from advertData
"""

import firebase_admin
from firebase_admin import credentials, firestore
import os

# Initialize Firebase
script_dir = os.path.dirname(os.path.abspath(__file__))
creds_path = os.path.join(script_dir, '..', 'medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
cred = credentials.Certificate(creds_path)

try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 80)
print("ROLLING BACK GHL STATS IN ads COLLECTION")
print("=" * 80)
print()

# ============================================================================
# STEP 1: Fetch original GHL stats from advertData
# ============================================================================

print("📊 STEP 1: Fetching original GHL stats from advertData...")
print()

ad_original_stats = {}

# Get all months
months_ref = db.collection('advertData').stream()

for month_doc in months_ref:
    month_id = month_doc.id
    print(f"   Processing month: {month_id}")
    
    # Get all ads in this month
    ads_ref = db.collection('advertData').document(month_id).collection('ads').stream()
    
    for ad_doc in ads_ref:
        ad_id = ad_doc.id
        ad_data = ad_doc.to_dict()
        
        # Get GHL stats from advertData
        ghl_stats = ad_data.get('ghlStats', {})
        fb_stats = ad_data.get('facebookStats', {})
        
        # Store original stats (keep the most recent month's data if duplicate)
        if ad_id not in ad_original_stats:
            ad_original_stats[ad_id] = {
                'ghlStats': ghl_stats,
                'facebookStats': fb_stats,
                'profit': ad_data.get('profit', 0),
                'cpl': ad_data.get('cpl', 0),
                'cpb': ad_data.get('cpb', 0),
                'cpa': ad_data.get('cpa', 0)
            }

print(f"✅ Found original stats for {len(ad_original_stats)} ads")
print()

# ============================================================================
# STEP 2: Restore GHL stats in ads collection
# ============================================================================

print("📊 STEP 2: Restoring GHL stats in ads collection...")
print()

batch = db.batch()
batch_count = 0
ads_restored = 0

for ad_id, original_data in ad_original_stats.items():
    ad_ref = db.collection('ads').document(ad_id)
    ad_doc = ad_ref.get()
    
    if not ad_doc.exists:
        continue
    
    # Restore original GHL stats
    batch.update(ad_ref, {
        'ghlStats': original_data['ghlStats'],
        'profit': original_data['profit'],
        'cpl': original_data['cpl'],
        'cpb': original_data['cpb'],
        'cpa': original_data['cpa']
    })
    
    batch_count += 1
    ads_restored += 1
    
    if batch_count >= 500:
        batch.commit()
        print(f"   ✅ Committed batch ({ads_restored} ads restored so far)")
        batch = db.batch()
        batch_count = 0

if batch_count > 0:
    batch.commit()

print()
print(f"✅ Restored {ads_restored} ads to original GHL stats")
print()

print("=" * 80)
print("✅ ROLLBACK COMPLETE!")
print("=" * 80)
print()

