#!/usr/bin/env python3
"""
Check the actual names of the 7 unmatched opportunities in Firestore
"""

import firebase_admin
from firebase_admin import credentials, firestore
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

print("=" * 80)
print("CHECKING 7 UNMATCHED OPPORTUNITIES IN FIRESTORE")
print("=" * 80)
print()

# The 7 unmatched opportunity IDs
unmatched_opp_ids = [
    '9pSST9D8T9sXbc0UE3TE',  # 2025-10-31
    'S7EIEHgGOXveSOc6oI6J',  # 2025-10-10
    'hkDLuzVBrtWvg8k6llPu',  # 2025-10-02
    '70fAPccPEMYz573hjpI2',  # 2025-09-29
    'dLujAaES4Pn2ZsBhV9QS',  # 2025-09-25
    'tXDpjz17dl4bRRJKNpbV',  # 2025-09-24
    'rlNpH8mOv2ijTJd8UD3P',  # 2025-09-16
]

for i, opp_id in enumerate(unmatched_opp_ids, 1):
    print(f"{i}. Opportunity ID: {opp_id}")
    
    # Get opportunity from Firestore
    opp_doc = db.collection('ghlOpportunities').document(opp_id).get()
    
    if not opp_doc.exists:
        print(f"   ❌ NOT FOUND in ghlOpportunities collection")
        print()
        continue
    
    opp_data = opp_doc.to_dict()
    
    # Print all fields
    print(f"   Name: {opp_data.get('name', 'MISSING')}")
    print(f"   Contact ID: {opp_data.get('contactId', 'MISSING')}")
    print(f"   Pipeline: {opp_data.get('source', 'MISSING')}")
    print(f"   Pipeline ID: {opp_data.get('pipelineId', 'MISSING')}")
    print(f"   Status: {opp_data.get('status', 'MISSING')}")
    print(f"   Created: {opp_data.get('createdAt', 'MISSING')}")
    print(f"   Assigned Ad ID: {opp_data.get('assignedAdId', 'NOT ASSIGNED')}")
    print(f"   Assignment Method: {opp_data.get('assignmentMethod', 'NONE')}")
    
    # Check if there are attributions
    attributions = opp_data.get('attributions', [])
    if attributions:
        print(f"   Attributions: {len(attributions)} found")
        for j, attr in enumerate(attributions, 1):
            print(f"      Attribution {j}: {json.dumps(attr, indent=10)}")
    else:
        print(f"   Attributions: NONE")
    
    print()

print("=" * 80)
print("CHECK COMPLETE")
print("=" * 80)

