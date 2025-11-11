#!/usr/bin/env python3
"""
Rollback split collections migration

This script deletes all documents from the new split collections
and restores the system to use advertData only.

WARNING: This is a destructive operation. Use only if migration failed.
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase
if not firebase_admin._apps:
    cred = credentials.Certificate('medx-ai-firebase-adminsdk-fbsvc-a86e7bd050.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

print("=" * 100)
print("SPLIT COLLECTIONS ROLLBACK")
print("=" * 100)
print()
print("⚠️  WARNING: This will delete all data from the new collections:")
print("   - campaigns")
print("   - adSets")
print("   - ads")
print("   - ghlOpportunities")
print("   - ghlOpportunityMapping")
print()
print("   The advertData collection will remain untouched.")
print()

# Ask for confirmation
confirmation = input("Type 'ROLLBACK' to confirm deletion: ")

if confirmation != 'ROLLBACK':
    print("❌ Rollback cancelled")
    exit(0)

print()
print("🔥 Starting rollback...")
print()

# Statistics
stats = {
    'campaigns_deleted': 0,
    'ad_sets_deleted': 0,
    'ads_deleted': 0,
    'opportunities_deleted': 0,
    'mappings_deleted': 0
}

def delete_collection(collection_name, batch_size=500):
    """Delete all documents in a collection"""
    deleted = 0
    collection_ref = db.collection(collection_name)
    
    while True:
        docs = list(collection_ref.limit(batch_size).stream())
        
        if not docs:
            break
        
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
            deleted += 1
        
        batch.commit()
        print(f"   Deleted {deleted} documents from {collection_name}...")
    
    return deleted

# ============================================================================
# Delete campaigns
# ============================================================================

print("🗑️  Deleting campaigns collection...")
stats['campaigns_deleted'] = delete_collection('campaigns')
print(f"✅ Deleted {stats['campaigns_deleted']} campaigns")
print()

# ============================================================================
# Delete adSets
# ============================================================================

print("🗑️  Deleting adSets collection...")
stats['ad_sets_deleted'] = delete_collection('adSets')
print(f"✅ Deleted {stats['ad_sets_deleted']} ad sets")
print()

# ============================================================================
# Delete ads
# ============================================================================

print("🗑️  Deleting ads collection...")
stats['ads_deleted'] = delete_collection('ads')
print(f"✅ Deleted {stats['ads_deleted']} ads")
print()

# ============================================================================
# Delete ghlOpportunities
# ============================================================================

print("🗑️  Deleting ghlOpportunities collection...")
stats['opportunities_deleted'] = delete_collection('ghlOpportunities')
print(f"✅ Deleted {stats['opportunities_deleted']} opportunities")
print()

# ============================================================================
# Delete ghlOpportunityMapping
# ============================================================================

print("🗑️  Deleting ghlOpportunityMapping collection...")
stats['mappings_deleted'] = delete_collection('ghlOpportunityMapping')
print(f"✅ Deleted {stats['mappings_deleted']} mappings")
print()

# ============================================================================
# SUMMARY
# ============================================================================

print("=" * 100)
print("ROLLBACK COMPLETE")
print("=" * 100)
print()
print(f"✅ Campaigns deleted: {stats['campaigns_deleted']}")
print(f"✅ Ad sets deleted: {stats['ad_sets_deleted']}")
print(f"✅ Ads deleted: {stats['ads_deleted']}")
print(f"✅ Opportunities deleted: {stats['opportunities_deleted']}")
print(f"✅ Mappings deleted: {stats['mappings_deleted']}")
print()
print("=" * 100)
print("NEXT STEPS:")
print("1. Verify advertData collection is intact")
print("2. Update Cloud Functions to disable split collections writes")
print("3. Update Flutter app to use advertData only")
print("4. Investigate migration issues before retrying")
print("=" * 100)

# Save rollback log
import json

rollback_log = {
    'timestamp': datetime.now().isoformat(),
    'deleted_counts': stats,
    'status': 'completed'
}

log_filename = f"rollback_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
with open(log_filename, 'w') as f:
    json.dump(rollback_log, f, indent=2)

print(f"\n📄 Rollback log saved to: {log_filename}")

