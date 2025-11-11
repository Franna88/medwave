#!/usr/bin/env python3
"""
Delete the 7 incomplete/corrupted opportunities from ghlOpportunities collection
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
print("DELETING 7 INCOMPLETE OPPORTUNITIES FROM ghlOpportunities")
print("=" * 80)
print()

# The 7 incomplete opportunity IDs (missing name, source, status, attributions)
incomplete_opp_ids = [
    '9pSST9D8T9sXbc0UE3TE',  # 2025-10-31
    'S7EIEHgGOXveSOc6oI6J',  # 2025-10-10
    'hkDLuzVBrtWvg8k6llPu',  # 2025-10-02
    '70fAPccPEMYz573hjpI2',  # 2025-09-29
    'dLujAaES4Pn2ZsBhV9QS',  # 2025-09-25
    'tXDpjz17dl4bRRJKNpbV',  # 2025-09-24
    'rlNpH8mOv2ijTJd8UD3P',  # 2025-09-16
]

deleted_count = 0
not_found_count = 0

for i, opp_id in enumerate(incomplete_opp_ids, 1):
    print(f"{i}/7: Deleting opportunity {opp_id}...")
    
    # Check if it exists first
    opp_doc = db.collection('ghlOpportunities').document(opp_id).get()
    
    if not opp_doc.exists:
        print(f"   ⚠️  Not found (already deleted?)")
        not_found_count += 1
        continue
    
    # Get the data to show what we're deleting
    opp_data = opp_doc.to_dict()
    contact_id = opp_data.get('contactId', 'N/A')
    created_at = opp_data.get('createdAt', 'N/A')
    
    print(f"   Contact ID: {contact_id}")
    print(f"   Created: {created_at}")
    
    # Delete the document
    db.collection('ghlOpportunities').document(opp_id).delete()
    
    print(f"   ✅ Deleted")
    deleted_count += 1
    print()

print("=" * 80)
print("DELETION COMPLETE")
print("=" * 80)
print()
print(f"Summary:")
print(f"  - Deleted: {deleted_count}")
print(f"  - Not found: {not_found_count}")
print(f"  - Total processed: {len(incomplete_opp_ids)}")
print()

# Verify deletion
print("🔍 Verifying deletion...")
remaining = 0
for opp_id in incomplete_opp_ids:
    if db.collection('ghlOpportunities').document(opp_id).get().exists:
        print(f"   ⚠️  {opp_id} still exists!")
        remaining += 1

if remaining == 0:
    print("   ✅ All 7 incomplete opportunities successfully deleted")
else:
    print(f"   ⚠️  {remaining} opportunities still exist")

print()
print("=" * 80)

